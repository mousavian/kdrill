# Header manipulation and URL rewrites

## Concept

A proxy at the edge usually changes requests on the way in: public URL
layout differs from the internal one, internal services expect a certain
Host, trusted metadata is added and untrusted client headers are dropped.

**Rewrites** are part of the route action and apply after the route is chosen:

- `prefix_rewrite: "/"`: replace the matched prefix (`/api/v1/users` matched by
  `prefix: "/api/"` becomes `/v1/users`). The query string stays.
- `regex_rewrite`: RE2 pattern + substitution for anything more complex.
- `host_rewrite_literal`, `host_rewrite_header`,
  `auto_host_rewrite` (use the upstream host's name): change the Host /
  `:authority` sent upstream.

**Header edits** can be set on the route configuration, a virtual host or a
route, for requests and responses:

- `request_headers_to_add` / `response_headers_to_add`: a list of
  `{header: {key, value}, append_action}`. `append_action` is
  `APPEND_IF_EXISTS_OR_ADD` (default), `ADD_IF_ABSENT`,
  `OVERWRITE_IF_EXISTS_OR_ADD` or `OVERWRITE_IF_EXISTS`.
- `request_headers_to_remove` / `response_headers_to_remove`.
- Values may use command operators: `%REQ(header)%`,
  `%DOWNSTREAM_REMOTE_ADDRESS_WITHOUT_PORT%`, `%UPSTREAM_HOST%`, ...

Security angle: a backend that trusts a header (who the user is, which
environment, which tenant) must only ever get the value the proxy set.
With the default append action a client can smuggle in its own value next
to yours.

Envoy also manages some headers itself: `x-request-id` (kept if the client
sent one, generated otherwise, the key for tracing and log correlation),
`x-forwarded-proto`, `x-forwarded-for` (appended when `use_remote_address`
is on), and `x-envoy-*` headers.

## The situation

Envoy forwards `/api/...` unchanged to the `api` backend, which prints the
request it received (request line, Host and all headers).

## Your task

For requests to `/api/...`, the backend must receive:

- the path without the `/api` prefix (`/api/v1/users?page=2` arrives as
  `/v1/users?page=2`);
- `Host: api.internal`;
- exactly one `x-env` header with the value `lab`, even if the client sent
  its own `x-env`;
- no `x-debug-token` header;
- the client's `x-request-id` unchanged.

The client must receive the response header `x-served-by: envoy-lab`.
Paths outside `/api/` still get 404.

## Useful commands

    kubectl exec client -- curl -s 'http://envoy:10000/api/v1/users?page=2' -H 'x-env: prod' -H 'x-debug-token: s3cr3t'
    kubectl exec client -- curl -si http://envoy:10000/api/v1/users | head -12
    kubectl edit configmap envoy
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy

When you think you're done: `kdrill verify`

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_conn_man/headers
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_conn_man/header_sanitizing
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/route/v3/route_components.proto#envoy-v3-api-field-config-route-v3-routeaction-prefix-rewrite
