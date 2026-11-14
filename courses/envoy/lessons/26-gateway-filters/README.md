# HTTPRoute filters: rewrites, header modifiers, redirects, mirroring

## Concept

A rule's `filters` change requests and responses on the way through. The
core and extended filters of the Gateway API:

- **`URLRewrite`**: change the path (`ReplaceFullPath` or
  `ReplacePrefixMatch`) and/or the `hostname` sent to the backend;
- **`RequestHeaderModifier`** / **`ResponseHeaderModifier`**: `set`
  (overwrite), `add` (append, keeping a client's value), `remove`;
- **`RequestRedirect`**: answer with a redirect (scheme, hostname, port,
  path, `statusCode` 301/302/303/307/308) instead of proxying; such a rule
  has no backendRefs;
- **`RequestMirror`**: send a copy of each request to another backend and
  discard its answer (shadow traffic, for testing a new version or warming
  a cache with real traffic);
- **`ExtensionRef`**: implementation-specific filters (Envoy Gateway's
  `HTTPRouteFilter`).

Filters run in the order listed. They're the portable version of what you
configured in Envoy by hand in lessons 12 and 13, and Envoy Gateway turns
them into exactly those Envoy fields.

The same security point as in lesson 12 applies: for headers a backend
trusts, use `set`, never `add`.

## The situation

Gateway `edge` with two HTTPRoutes: `api` (host `api.lab`, prefix `/api`
to the `api` backend, unchanged) and `old` (host `old.lab`, also to api).
A second deployment `api-shadow` (`Name: shadow`) is meant to receive
copies of the API traffic.

## Your task

For `api.lab/api/...`, using filters on the HTTPRoute `api`:

- the `api` backend receives the path without `/api`
  (`/api/v1/users?page=2` arrives as `/v1/users?page=2`), `Host:
  api.internal`, exactly one `x-env: lab` (even if the client sent one), and
  no `x-debug-token`;
- the client gets the response header `x-served-by: envoy-gateway`;
- every request is mirrored to `api-shadow` (verify counts them in Envoy's
  stats).

For `old.lab`, any request gets a 301 to `https://new.lab` with the same
path and query.

## Useful commands

    kubectl exec client -- curl -s 'http://edge/api/v1/users?page=2' -H 'Host: api.lab' -H 'x-env: prod' -H 'x-debug-token: s3cr3t'
    kubectl exec client -- curl -si http://edge/products/7 -H 'Host: old.lab'
    kubectl explain httproute.spec.rules.filters
    kubectl port-forward deploy/edge 19000 &  curl -s localhost:19000/clusters | grep rq_total

When you think you're done: `kdrill verify`

## Read more

- https://gateway-api.sigs.k8s.io/reference/api-spec/main/spec/
- https://gateway.envoyproxy.io/v1.9/tasks/traffic/http-urlrewrite/
- https://gateway.envoyproxy.io/v1.9/tasks/traffic/http-request-headers/
- https://gateway.envoyproxy.io/v1.9/tasks/traffic/http-request-mirroring/
