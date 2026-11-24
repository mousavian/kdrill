# Chaos testing: fault injection

## Concept

Timeouts, retries and fallbacks are only trustworthy once you have watched
them work. **Fault injection** lets the mesh break things on purpose,
without changing the service: the client sidecar delays or aborts requests
before they ever leave the Pod.

    http:
    - match:
      - headers: {x-chaos: {exact: abort}}
      fault:
        abort:
          httpStatus: 503              # or grpcStatus
          percentage: {value: 100}
        # delay:
        #   fixedDelay: 2s
        #   percentage: {value: 10}
      route:
      - destination: {host: ratings}

- **abort** answers immediately with the given status. Envoy writes the body
  `fault filter abort` and the access log shows the response flag `FI`.
- **delay** holds the request for `fixedDelay`, then sends it on normally
  (flag `DI`).
- **percentage** applies the fault to that share of matching requests.
  Without it, the fault applies to 100%.
- Delay and abort can be combined in one route.

Scope faults with `match`: by header (test traffic only), by source
(`sourceLabels`), by path. A fault on the catch-all route hits every user.

Faults are injected in the **caller's** sidecar, so they test the caller's
reaction (its timeouts, retries, fallbacks). Retries configured on the same
route do not retry an injected abort; the fault filter runs before the
router.

## The situation

Namespace `shop` has the curl client `web` and the service `ratings`; the
VirtualService `ratings` has one plain route `main`.

## Your task

Extend VirtualService `ratings` so that, for requests from inside the mesh:

- `x-chaos: abort` gets an immediate 503 from the mesh (all of them);
- `x-chaos: delay` gets a 2 s delay and then the normal answer;
- `x-chaos: flaky` fails with 500 about half of the time (50%);
- every other request, including other values of `x-chaos`, is untouched.

## Useful commands

    kubectl -n shop exec deploy/web -c curl -- curl -s -w '\n%{http_code} %{time_total}s\n' -H 'x-chaos: abort' ratings:8000/get
    kubectl -n shop exec deploy/web -c curl -- sh -c 'for i in $(seq 20); do curl -s -o /dev/null -w "%{http_code} " -H "x-chaos: flaky" ratings:8000/get; done; echo'
    istioctl proxy-config routes deploy/web -n shop --name 8000 -o json | grep -B3 -A15 '"envoy.filters.http.fault"'

When you think you're done: `kdrill verify`

## On a real cluster

Run fault experiments in a staging environment or behind a header that only
your test traffic carries, start with small percentages, and watch
dashboards while they run. Chaos tools (Litmus, Chaos Mesh) can drive
Istio faults on a schedule.

## Read more

- https://istio.io/latest/docs/tasks/traffic-management/fault-injection/
- https://istio.io/latest/docs/reference/config/networking/virtual-service/#HTTPFaultInjection
- https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/fault_filter
