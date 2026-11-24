# Solution

From the lesson directory:

    kubectl apply -f solution/gateway.yaml -f solution/referencegrant.yaml
    kubectl label ns lab gateway-access=public

Two independent permission checks guard cross-namespace routing, and each
side of the relationship owns one of them:

| Reference | Who must allow it | How |
|---|---|---|
| HTTPRoute (lab) to Gateway (infra) | the Gateway owner | `listeners[].allowedRoutes.namespaces`: `Same` (default), `All`, or `Selector` |
| HTTPRoute (lab) to Service (reviews) | the Service owner | a `ReferenceGrant` in `reviews` naming `from: HTTPRoute in lab`, `to: Service` |

Status tells you which one is missing: the route's parent condition
`Accepted=False, reason NotAllowedByListeners`, and `ResolvedRefs=False,
reason RefNotPermitted`. A route whose backend is not permitted is still
programmed, but requests for that rule get a 500 from Envoy Gateway.

`sandbox` has no label, so its `sneaky` route stays unaccepted and can't
take `/admin` on the shop's host name. With `from: All`, it could have:
any namespace could publish any path under any host the listener allows.
Hostnames are a shared resource on a shared Gateway; a selector (or one
listener per team with its own `hostname`) keeps teams apart.

The listener's `hostname: "*.lab"` also filters routes: a route for
`shop.example.com` would not attach (`NoMatchingListenerHostname`).

Takeaways: the Gateway decides who may attach; the target namespace decides
who may reference it (ReferenceGrant); and both show up in route status,
not as errors anywhere else.
