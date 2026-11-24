# Shared Gateways: cross-namespace routes and ReferenceGrant

## Concept

The usual setup: the platform team runs a few shared Gateways in their own
namespace, app teams attach HTTPRoutes from theirs. Gateway API makes both
sides opt in.

**Who may attach to a listener** is the Gateway's call:

    listeners:
    - name: http
      port: 80
      protocol: HTTP
      hostname: "*.lab"              # routes must fit under this hostname
      allowedRoutes:
        namespaces:
          from: Selector             # Same (the default) | All | Selector
          selector:
            matchLabels: {gateway-access: public}

An HTTPRoute names its Gateway in `parentRefs` (with `namespace:` when it
lives elsewhere). If the listener doesn't allow it, the route's status
says `Accepted: False, NotAllowedByListeners` and no traffic flows.

**Who may point at a Service in another namespace** is the Service owner's
call: a **ReferenceGrant** in the *target* namespace lists which kinds from
which namespaces may reference which objects there:

    apiVersion: gateway.networking.k8s.io/v1beta1
    kind: ReferenceGrant
    metadata: {name: allow-x, namespace: target-ns}
    spec:
      from: [{group: gateway.networking.k8s.io, kind: HTTPRoute, namespace: app-ns}]
      to:   [{group: "", kind: Service}]          # optional name: one Service

Without it the route reports `ResolvedRefs: False, RefNotPermitted` and that
rule answers 500. The same mechanism lets a Gateway use a TLS Secret from
another namespace (lesson 29).

Envoy Gateway runs each Gateway's Envoy in the Gateway's own namespace, so
a shared Gateway `public` in `infra` is reached as `http://public.infra`.

## The situation

- `infra`: Gateway `public` (HTTP :80, hostname `*.lab`), owned by the
  platform team. Its listener has no `allowedRoutes`, so only routes from
  `infra` may attach.
- `lab` (the shop team): Service `web`, the `client` pod, and HTTPRoute
  `storefront` for `shop.lab` (`/` goes to `web`, `/reviews` to Service
  `reviews` in namespace `reviews`).
- `reviews`: Service `reviews`, owned by the reviews team.
- `sandbox`: an experiment whose HTTPRoute `sneaky` tries to take
  `shop.lab/admin` on the same Gateway.

## Your task

- Let Gateway `public` accept routes from every namespace labelled
  `gateway-access=public` (and only those), keeping its hostname.
- Label namespace `lab` accordingly. `sandbox` stays unlabelled, so its
  route must not be accepted.
- Allow HTTPRoutes in `lab` to use Service `reviews` in `reviews`.

Then `shop.lab/` reaches `web`, `/reviews/...` reaches `reviews`, and
`/admin` gets a 404.

## Useful commands

    kubectl describe httproute storefront
    kubectl -n sandbox describe httproute sneaky
    kubectl -n infra edit gateway public
    kubectl label ns lab gateway-access=public
    kubectl explain referencegrant.spec
    kubectl get httproute -A
    kubectl exec client -- hits -n 6 http://public.infra/reviews/list -H 'Host: shop.lab'

When you think you're done: `kdrill verify`

## Read more

- https://gateway-api.sigs.k8s.io/guides/multiple-ns/
- https://gateway-api.sigs.k8s.io/api-types/referencegrant/
- https://gateway-api.sigs.k8s.io/concepts/security-model/
