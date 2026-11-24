Measure the failure rate and look at the sick host:

    kubectl exec client -- hits -n 30 http://envoy:10000/items
    kubectl exec client -- curl -s envoy:9901/clusters | grep -E 'rq_total|rq_error'

A retry policy lives on the route action:

    route:
      cluster: echo
      retry_policy:
        retry_on: "5xx"
        num_retries: 2
---
Two more requirements:
- A retry should go to a different host: `retry_host_predicate` with
  `envoy.retry_host_predicates.previous_hosts` (typed_config
  `type.googleapis.com/envoy.extensions.retry.host.previous_hosts.v3.PreviousHostsPredicate`)
  and `host_selection_retry_max_attempts: 3`.
- Only GET: Envoy retries any method. Match the method with a header
  matcher on the pseudo-header `:method` (`string_match: {exact: GET}`) in a
  first route that has the retry policy, and keep a second route
  `prefix: "/"` without one.
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
