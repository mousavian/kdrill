# Solution

From the lesson directory:

    kubectl apply -f solution/routes.yaml

The `/api` rule:

    filters:
    - type: URLRewrite
      urlRewrite:
        hostname: api.internal
        path: {type: ReplacePrefixMatch, replacePrefixMatch: /}
    - type: RequestHeaderModifier
      requestHeaderModifier:
        set: [{name: x-env, value: lab}]
        remove: [x-debug-token]
    - type: ResponseHeaderModifier
      responseHeaderModifier:
        add: [{name: x-served-by, value: envoy-gateway}]
    - type: RequestMirror
      requestMirror:
        backendRef: {name: api-shadow, port: 80}

and the `old.lab` rule is just a `RequestRedirect` (`scheme: https`,
`hostname: new.lab`, `statusCode: 301`) without backends.

How they map to Envoy (compare with lessons 12 and 13): URLRewrite becomes
`prefix_rewrite` (or `regex_rewrite`) and `host_rewrite_literal`; the header
modifiers become `request_headers_to_add` with `OVERWRITE_IF_EXISTS_OR_ADD`
for `set` and `APPEND_IF_EXISTS_OR_ADD` for `add`, plus
`request_headers_to_remove`; RequestRedirect becomes a `redirect` route
action; RequestMirror becomes `request_mirror_policies` with its own
cluster (`httproute/lab/api/rule/0-mirror-3` in `/clusters`).

Notes:
- Envoy Gateway also adds `X-Forwarded-Host: api.lab` when it rewrites the
  host, and `X-Forwarded-For` / `X-Envoy-External-Address` (lesson 32).
- Mirrored requests are fire-and-forget: Envoy doesn't wait for the shadow,
  ignores its answer, and doesn't retry it. The shadow must not cause side
  effects (don't mirror payments to a backend that charges cards).
  `requestMirror.percent`/`fraction` mirrors only a share.
- Envoy Gateway's own `HTTPRouteFilter` resource (an `ExtensionRef` filter)
  adds things the core API lacks: regex path rewrites, direct responses,
  credential injection.
