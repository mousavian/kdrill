# Direct responses and redirects: answers without a backend

## Concept

A route's action doesn't have to be `route:` (forward to a cluster). Two
other actions let Envoy answer by itself:

- **`direct_response`**: a fixed status and optional body
  (`{status: 200, body: {inline_string: "ok\n"}}`). For health endpoints,
  maintenance pages, blocking a path (403/404), or `robots.txt`.
- **`redirect`**: a 3xx with a `Location` header built from the request and
  the fields you set: `scheme_redirect` or `https_redirect: true`,
  `host_redirect`, `port_redirect`, and one of `path_redirect` (replace the
  whole path) or `prefix_rewrite` (replace the matched prefix);
  `strip_query`; `response_code` (`MOVED_PERMANENTLY` 301 is the default,
  `FOUND` 302, `SEE_OTHER` 303, `TEMPORARY_REDIRECT` 307,
  `PERMANENT_REDIRECT` 308). Path and query are kept unless you change them.

Typical edge jobs: send HTTP to HTTPS, move a domain (`old.lab` to
`new.lab`), move a section (`/blog/*` to `/news/*`), and give unknown hosts
a real answer through a catch-all virtual host (`domains: ["*"]`) instead
of Envoy's empty 404.

301 and 302 allow clients to change POST to GET when following; 307 and 308
keep the method and body, so they're the safe choice for APIs.

The HCM can also reshape Envoy's own error answers (404 no route, 503 no
healthy upstream, ...) with `local_reply_config`, e.g. into JSON.

## The situation

Envoy serves `new.lab` and `old.lab`, both proxied to the `web` backend.
Unknown hosts get Envoy's empty 404. There's no health endpoint.

## Your task

- `GET /healthz` returns 200 with body `ok` on every host (`new.lab`,
  `old.lab` and unknown hosts), answered by Envoy without touching the
  backend;
- any request to `old.lab` gets a 301 to `https://new.lab` with the same path
  and query;
- `new.lab/blog/<rest>` gets a 308 to `/news/<rest>` (same host);
- every other `new.lab` request still goes to the web backend;
- requests for unknown hosts get 404 with the body `no such site`.

## Useful commands

    kubectl exec client -- curl -si http://envoy:10000/products/7?x=1 -H 'Host: old.lab'
    kubectl exec client -- curl -si http://envoy:10000/blog/2024/hello -H 'Host: new.lab'
    kubectl exec client -- curl -si http://envoy:10000/healthz -H 'Host: whatever.example'
    kubectl edit configmap envoy

When you think you're done: `kdrill verify`

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/route/v3/route_components.proto#config-route-v3-redirectaction
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-v3/config/route/v3/route_components.proto#config-route-v3-directresponseaction
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_conn_man/local_reply
