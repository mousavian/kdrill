# Solution

    kubectl apply -f solution/policy.yaml      # from the lesson directory

`approved-namespace` now reads the Namespace object at admission time:

    context:
    - name: nsApproval
      apiCall:
        urlPath: "/api/v1/namespaces/{{ request.namespace }}"
        jmesPath: "metadata.labels.\"gpu-access\" || ''"

The API call runs as Kyverno's admission controller ServiceAccount (it can
read Namespaces); `jmesPath` trims the response to just the label, with `''`
when it is missing. Approving a team is now `kubectl label ns X
gpu-access=approved`, done by whoever may label namespaces.

`max-gpus-per-pod` loads the ConfigMap:

    context:
    - name: gpuPolicy
      configMap: {name: gpu-policy, namespace: platform}

and uses `{{ gpuPolicy.data."max-gpus-per-pod" }}` in the condition and the
message. The left side sums the GPU limits of all containers:
`sum(request.object.spec.containers[].to_number(resources.limits."nvidia.com/gpu" || '0'))`.

Notes:
- Every lookup is a request to the API server on the admission path. Keep
  lookups behind preconditions (only GPU Pods pay here). For heavy or shared
  data use a GlobalContextEntry (cached by Kyverno) or ConfigMaps with the
  `cache.kyverno.io/enabled: "true"` label.
- `apiCall` can also call a Service (`service.url`) or any URL, e.g. an
  internal allow-list API, and can `POST` data.
- If a lookup fails (object missing), the rule errors. Use `default:` on the
  context entry when a missing value should not block.

Takeaways: policies hold the logic; data that changes (allow-lists,
limits, approvals) lives in Kubernetes objects or services owned by the
right team.
