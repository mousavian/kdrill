Filters go into a rule, next to `matches` and `backendRefs`, and run in
order:

    filters:
    - type: URLRewrite
      urlRewrite: {...}
    - type: RequestHeaderModifier
      requestHeaderModifier: {set: [...], add: [...], remove: [...]}

`kubectl explain httproute.spec.rules.filters` lists all filter types.
---
- `URLRewrite`: `hostname: api.internal`,
  `path: {type: ReplacePrefixMatch, replacePrefixMatch: /}`.
- `RequestHeaderModifier`: `set: [{name: x-env, value: lab}]`,
  `remove: [x-debug-token]`.
- `ResponseHeaderModifier`: `add: [{name: x-served-by, value: envoy-gateway}]`.
- `RequestMirror`: `backendRef: {name: api-shadow, port: 80}`.
- Route `old`: a rule with only a `RequestRedirect` filter
  (`scheme: https`, `hostname: new.lab`, `statusCode: 301`) and no backendRefs.
---
    kubectl apply -f solution/routes.yaml      # from the lesson directory
