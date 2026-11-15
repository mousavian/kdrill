    kubectl exec client -- ask -m small http://edge/v1/chat/completions
    kubectl exec client -- ask -m large http://edge/v1/chat/completions      # 404: the small server does not know "large"

The gateway matches on headers and paths, not on the body. So two steps: something must copy the body's
"model" field into a header, and then the route can match that header.
`kubectl explain envoyextensionpolicy.spec.lua` : an inline Lua script can read `handle:body()` and
set `handle:headers():replace("x-model", value)`.
---
1. EnvoyExtensionPolicy (targetRefs: Gateway edge) with a Lua `envoy_on_request(handle)` that reads
   the body, extracts `"model": "..."` with `string.match` and calls `handle:headers():replace("x-model", m)`
   (replace, so a client cannot choose its own).
2. HTTPRoute `llm`: one rule per model with `matches: [{headers: [{name: x-model, value: small}]}]`
   and its own backendRef.
3. A last rule without matches that answers 404 itself: an `HTTPRouteFilter` (`kubectl explain httproutefilter.spec.directResponse`)
   referenced with `filters: [{type: ExtensionRef, extensionRef: {group: gateway.envoyproxy.io, kind: HTTPRouteFilter, name: ...}}]`.
   Careful: with no catch-all at all, Envoy Gateway never runs the Lua filter (it is enabled per matched route).
---
    kubectl apply -f solution/route.yaml        # from the lesson directory
    kubectl apply -f solution/bbr.yaml
