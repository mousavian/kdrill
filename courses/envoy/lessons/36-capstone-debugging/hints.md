Start with the cheapest evidence, the status of every object:

    kubectl get gateway,httproute -A
    kubectl get httproute -o custom-columns='NAME:.metadata.name,ACCEPTED:.status.parents[0].conditions[?(@.type=="Accepted")].reason,REFS:.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason'
    kubectl get backendtrafficpolicy -o yaml | grep -A3 conditions

Two routes tell you exactly what's wrong in their status. For the others,
send a request and read Envoy's answer and its access log:

    for h in www api pay reports checkout; do kubectl exec client -- curl -s -o /dev/null -w "$h %{http_code}\n" http://edge/ -H "Host: $h.lab"; done
    kubectl logs deploy/edge -c envoy --tail=10      # response_flags, upstream_cluster
---
- `web`: `NoMatchingParent`: the route asks for a listener `https`.
- `api`: `ResolvedRefs: False`: compare the backendRef port with `kubectl get svc api`.
- `pay`: `RefNotPermitted`: a route may only reference a Service in another
  namespace if that namespace has a ReferenceGrant allowing it.
- `reports`: access log `UH`, and `/clusters` has no host for it: what
  does the Service select? (`kubectl get endpointslices -l kubernetes.io/service-name=reports`)
- `checkout`: also `UH`, but `/clusters` has the host, flagged
  `/failed_active_hc`. What does the health check expect, and what does
  `curl http://<checkout-pod-ip>/health` return?
  (`kubectl port-forward deploy/edge 19000` for the admin interface.)
---
    kubectl apply -f solution/sites.yaml      # from the lesson directory

Every fix is marked `# FIX n` in the file.
