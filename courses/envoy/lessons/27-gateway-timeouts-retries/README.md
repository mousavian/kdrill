# Timeouts on HTTPRoutes, retries with a BackendTrafficPolicy

## Concept

Some traffic policy is part of the Gateway API itself; the rest comes from
the implementation as **policy resources** that attach to Gateway API
objects ("policy attachment"):

- **Timeouts** are core: `rules[].timeouts.request` (the whole request,
  Envoy's route `timeout`) and `timeouts.backendRequest` (one attempt,
  Envoy's `per_try_timeout`).
- **Retries**, circuit breakers, load balancing, health checks, rate
  limits and more live in Envoy Gateway's **BackendTrafficPolicy** (how
  Envoy talks to backends). Its `targetRefs` name a Gateway, an HTTPRoute
  (optionally one rule via `sectionName`), or other route kinds. A policy on
  a route overrides one on its Gateway.

Policies report back too: `status.ancestors[]` lists, per Gateway, whether
the policy was `Accepted` and why not. A policy that targets a name that
doesn't exist is accepted by the API server and does nothing, so check its
status.

The retry settings map to the Envoy `retry_policy` you wrote in lesson 09:
`numRetries`, `retryOn.triggers` (`5xx`, `gateway-error`, `reset`,
`connect-failure`, `retriable-status-codes`, ...) with `httpStatusCodes`,
and `perRetry` (`timeout`, `backOff`). Retries count against the route's
request timeout.

## The situation

Gateway `edge`, HTTPRoute `api` (host `api.lab`) with rules for `/api`
and `/reports`, both to the Service `echo`. Behind `echo` are two healthy
pods and the pod `sick` (503 to everything, like lesson 07). Requests with
`?wait=3s` take 3 s.

## Your task

- `/api...`: a request timeout of 1 s on the HTTPRoute rule (a 3 s request
  gets 504 after about 1 s);
- `/reports...`: a request timeout of 10 s on the HTTPRoute rule;
- a BackendTrafficPolicy that targets the HTTPRoute `api`, is Accepted,
  and retries 503s up to 2 times: 60 GETs to `/api` all succeed and Envoy's
  retry counter shows it;
- leave the sick pod where it is.

## Useful commands

    kubectl exec client -- hits -n 30 http://edge/api/items -H 'Host: api.lab'
    kubectl exec client -- curl -s -o /dev/null -w '%{http_code} %{time_total}s\n' -H 'Host: api.lab' 'http://edge/api/items?wait=3s'
    kubectl explain backendtrafficpolicy.spec.retry
    kubectl get backendtrafficpolicy -o yaml
    kubectl port-forward deploy/edge 19000 &  curl -s 'localhost:19000/stats?filter=retry'

When you think you're done: `kdrill verify` (about 10 s).

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/traffic/http-timeouts/
- https://gateway.envoyproxy.io/v1.9/tasks/traffic/retry/
- https://gateway.envoyproxy.io/v1.9/api/extension_types/#backendtrafficpolicy
- https://gateway-api.sigs.k8s.io/reference/policy-attachment/
