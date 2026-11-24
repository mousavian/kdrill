# Canary releases with HTTPRoute weights

## Concept

The Gateway API puts traffic splitting into the core HTTPRoute:
`backendRefs` can list several backends with a **`weight`** each, and
requests are spread in proportion to the weights. Envoy Gateway
compiles that to Envoy's `weighted_clusters` (lesson 11), and because
config arrives over xDS, changing a weight takes effect in about a second.

A canary release combines:

- a **weighted rule** for everyone: 90/10, then 50/50, then 0/100, while
  you compare the versions' error rates and latency;
- an **opt-in rule** for testers and smoke tests: a header (or cookie)
  match that always sends to the new version. Thanks to match precedence
  (lesson 24), a rule with a header match beats the rule without matches,
  whatever the order.

Splitting is per request, and independent of replica counts: one canary
pod can take exactly 10%. Tools such as Argo Rollouts (Gateway API plugin)
and Flagger drive this automatically, editing the HTTPRoute weights based
on metrics. An Istio VirtualService expresses the same idea.

## The situation

Gateway `edge` and HTTPRoute `web` (`www.lab`) send everything to `web-v1`
(`Name: v1`). `web-v2` (`Name: v2`) is deployed.

## Your task

Change the HTTPRoute `web` so that:

- requests to `www.lab` go about 90% to web-v1 and 10% to web-v2, using
  backendRef weights 90 and 10 (verify sends 200 and accepts 6 to 36 for v2);
- requests with `x-canary: always` all go to web-v2; any other value of
  the header is treated like no header.

## Useful commands

    kubectl exec client -- hits -n 200 http://edge/ -H 'Host: www.lab'
    kubectl exec client -- hits -n 20 http://edge/ -H 'Host: www.lab' -H 'x-canary: always'
    kubectl edit httproute web

When you think you're done: `kdrill verify`

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/traffic/http-traffic-splitting/
- https://gateway-api.sigs.k8s.io/guides/traffic-splitting/
- https://gateway-api.sigs.k8s.io/reference/api-spec/main/spec/
