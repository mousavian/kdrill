# Capstone: five sites, five different failures

## Concept

Debugging Envoy behind a Gateway (or a mesh) is a layered search, and
every layer has its own evidence:

1. **Kubernetes objects and their status**: is the Gateway Programmed? Is
   each route Accepted by its parent (`NoMatchingParent`,
   `NotAllowedByListeners`, hostname mismatch)? Are its references
   resolved (`BackendNotFound`, port not found, `RefNotPermitted` for
   cross-namespace references without a **ReferenceGrant**)? Are policies
   Accepted, and do they target what you think?
2. **Envoy's answer and access log**: status code, body, and
   `response_flags` (`NR`, `UH`, `UF`, `UT`, `UO`, `URX`, `RL`, ...),
   `upstream_cluster`, `upstream_host`. Envoy Gateway logs JSON to the
   envoy container's stdout by default.
3. **The admin interface** (`kubectl port-forward deploy/edge 19000`):
   `/clusters` (which hosts, their `health_flags`), `/config_dump` (what
   was generated), `/stats` (`health_check.failure`, `upstream_cx_connect_fail`,
   `membership_healthy`, ...).
4. **Kubernetes plumbing**: Services, selectors, EndpointSlices, ports, pod
   readiness.

The fix belongs where the mistake is. Changing the workload or adding a
catch-all route to make a symptom disappear leaves the bug for the next
person.

A **ReferenceGrant** is how a namespace owner allows routes from another
namespace to use its Services (or Secrets): the target namespace has to
opt in, the source can't grant itself access.

## The situation

Gateway `edge` in `lab` with five HTTPRoutes:

1. `www.lab` to `web`;
2. `api.lab` to `api` (2 pods);
3. `pay.lab` to the Service `pay` owned by the payments team in namespace
   `payments`;
4. `reports.lab` to `reports` (the Service is defined next to the route);
5. `checkout.lab` to `checkout`, with an active health check on `/health`
   (BackendTrafficPolicy `checkout-health`).

All five fail.

## Your task

Make every site answer 200 from its own backend, with all five routes
Accepted and ResolvedRefs, by fixing routes, Services, policies or grants.
Rules: don't change the Deployments or pod labels; `pay.lab` keeps
routing to `payments/pay`; `checkout` keeps an active health check on
`/health`.

## Useful commands

    kubectl get gateway,httproute,backendtrafficpolicy -n lab
    kubectl get httproute -n lab -o yaml | less
    for h in www api pay reports checkout; do kubectl exec client -- curl -s -o /dev/null -w "$h %{http_code}\n" http://edge/ -H "Host: $h.lab"; done
    kubectl logs deploy/edge -c envoy --tail=10
    kubectl port-forward deploy/edge 19000 &   curl -s localhost:19000/clusters | grep -E 'cx_active|health_flags'
    kubectl get endpointslices -n lab

When you think you're done: `kdrill verify` (after a policy change it may
wait up to 25 s for the health check to pass).

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/operations/egctl/
- https://gateway-api.sigs.k8s.io/reference/api-types/referencegrant/
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/observability/access_log/usage#command-operators
- https://gateway.envoyproxy.io/v1.9/tasks/observability/proxy-accesslog/
