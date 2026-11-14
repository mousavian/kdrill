# Virtual hosts and routes: matching Host, path and headers

## Concept

The HCM's route configuration decides where each request goes, in two steps.

**1. Virtual host**, by the Host header (`:authority` in HTTP/2). Each
virtual host lists `domains`. Envoy picks, across all virtual hosts:
an exact match (`api.lab`), else the longest suffix wildcard (`*.lab`), else
the longest prefix wildcard (`api.*`), else `*`. No match: 404 from Envoy.
If the client sends a port (`Host: api.lab:10000`), it is part of what
is matched unless the route configuration sets
`ignore_port_in_host_matching: true` (Envoy Gateway sets it) or the HCM
strips ports (`strip_any_host_port`).

**2. Route**, inside the chosen virtual host. Routes are an ordered list and
the **first** route whose `match` holds wins. A `match` has exactly one
path specifier:

- `prefix: "/v2"`: plain string prefix; also matches `/v2beta`.
- `path: "/v2"`: exact path.
- `path_separated_prefix: "/v2"`: `/v2` or `/v2/...`, not `/v2beta`.
- `safe_regex: {regex: "^/users/[0-9]+$"}`: RE2 over the whole path.

and optional extra conditions that must all hold: `headers` (exact,
prefix, regex, present, inverted), `query_parameters`, `grpc`, and
`runtime_fraction`. The query string is never part of the path match.

Because the first match wins, write routes from most to least specific: a
`prefix: "/"` route at the top hides everything below it. Envoy doesn't warn
about unreachable routes.

The action is usually `route:` (forward to a cluster, with options you'll
meet later: timeouts, retries, rewrites, weighted clusters), or
`redirect:` / `direct_response:` (lesson 13).

## The situation

Namespace `lab` has backends `web`, `api-v1` and `api-v2` and an Envoy whose
route table is half done: `www.lab` works, but the API sends everything
to v1, and other hosts get 404.

## Your task

Change the route configuration in the ConfigMap `envoy` so that:

| Host | Request | Goes to |
|---|---|---|
| `lab`, `www.lab` | any path | web |
| any other `*.lab` (e.g. `blog.lab`) | any path | web |
| anything not under `.lab` (e.g. `example.com`) | any | 404 from Envoy |
| `api.lab` | header `x-api-version: 2`, any path | api-v2 |
| `api.lab` | `/v2` or `/v2/...` | api-v2 |
| `api.lab` | anything else, including `/v2beta/...` | api-v1 |

## Useful commands

    kubectl exec client -- hits -n 1 http://envoy:10000/v2/users -H 'Host: api.lab'
    kubectl exec client -- hits -n 1 http://envoy:10000/users -H 'Host: api.lab' -H 'x-api-version: 2'
    kubectl exec client -- curl -s 'envoy:9901/config_dump?resource=static_route_configs'
    kubectl edit configmap envoy
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

When you think you're done: `kdrill verify`

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/http/http_routing
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/route/v3/route_components.proto
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/route/v3/route.proto
