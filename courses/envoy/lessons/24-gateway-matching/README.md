# HTTPRoute matching: paths, headers, methods, query params, precedence

## Concept

An HTTPRoute has `hostnames` and a list of `rules`; each rule has
`matches` and `backendRefs`. Matching works like this:

- A request belongs to a route if its Host matches one of the route's
  `hostnames` (exact, or a wildcard like `*.lab` covering one or more
  labels). Exact hostnames take precedence over wildcards.
- A rule applies if **any** of its `matches` holds. Inside one match,
  **all** conditions must hold:
  - `path`: `PathPrefix` (by path *element*: `/v2` matches `/v2` and
    `/v2/x`, not `/v2beta`), `Exact`, or `RegularExpression`
    (implementation-specific syntax; RE2 in Envoy Gateway);
  - `method`;
  - `headers` and `queryParams`: Exact or RegularExpression.
  No `matches` at all means `PathPrefix: /`.

When several rules (from one or several routes) match, the order in the
YAML is **not** what decides. The spec defines precedence: Exact path,
then the longest PathPrefix, then a match with a method, then the largest
number of header matches, then of query param matches; only then creation
time and name. Envoy Gateway compiles this into an ordered Envoy route list,
so you get Envoy's first-match semantics with the most specific match first.
That's a difference from Part A, where you had to order routes yourself.

## The situation

Gateway `edge` with two HTTPRoutes: `web` for `www.lab`, and `api` for
`api.lab` that sends everything to `api-v1`. Backends `api-v2` and
`orders` are deployed but unused.

## Your task

| Host | Request | Goes to |
|---|---|---|
| `www.lab`, any other `*.lab` | any | web |
| not under `.lab` | any | 404 |
| `api.lab` | `/v2` or `/v2/...` | api-v2 |
| `api.lab` | header `x-api-version: 2` | api-v2 |
| `api.lab` | query `canary=true` | api-v2 |
| `api.lab` | `POST /orders` | orders |
| `api.lab` | anything else (incl. `GET /orders`, `/v2beta/...`) | api-v1 |

Both HTTPRoutes must stay Accepted with resolved references.

## Useful commands

    kubectl exec client -- hits -n 1 http://edge/v2/users -H 'Host: api.lab'
    kubectl exec client -- hits -n 1 http://edge/orders -H 'Host: api.lab' -X POST
    kubectl get httproute api -o yaml
    kubectl explain httproute.spec.rules.matches
    kubectl port-forward deploy/edge 19000 &  curl -s 'localhost:19000/config_dump?resource=dynamic_route_configs'

When you think you're done: `kdrill verify`

## Read more

- https://gateway-api.sigs.k8s.io/reference/api-types/httproute/#matches
- https://gateway-api.sigs.k8s.io/reference/api-spec/main/spec/
- https://gateway.envoyproxy.io/v1.9/tasks/traffic/http-routing/
