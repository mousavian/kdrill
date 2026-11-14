Both rules have hard-coded values: a namespace list and the number 8.
Kyverno can load data into variables before a rule runs:

    kubectl explain clusterpolicy.spec.rules.context
    kubectl explain clusterpolicy.spec.rules.context.apiCall
    kubectl explain clusterpolicy.spec.rules.context.configMap
    kubectl get --raw /api/v1/namespaces/ml-team | head -c 400     # what an apiCall returns
---
- `approved-namespace`: a context entry
  `{name: nsApproval, apiCall: {urlPath: "/api/v1/namespaces/{{ request.namespace }}", jmesPath: "metadata.labels.\"gpu-access\" || ''"}}`,
  then deny when `{{ nsApproval }}` NotEquals `approved`.
- `max-gpus-per-pod`: a context entry `{name: gpuPolicy, configMap: {name: gpu-policy, namespace: platform}}`;
  compare against `{{ gpuPolicy.data."max-gpus-per-pod" }}` and put the same
  variable in the message.
---
    kubectl apply -f solution/policy.yaml      # from the lesson directory

Try it: `kubectl label ns web-team gpu-access=approved` and the GPU Pod is
admitted there, no policy change.
