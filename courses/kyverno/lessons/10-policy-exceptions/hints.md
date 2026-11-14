Try the workload and look at the existing exception:

    kubectl apply -f manifests/dcgm-exporter.yaml          # rejected: autogen-disallow-host-path
    kubectl get policyexceptions -A
    kubectl -n kyverno get deploy kyverno-admission-controller -o yaml | grep -i exception

The exception in `gpu-operator` is ignored: this Kyverno only reads
exceptions from the namespace given by `--exceptionNamespace`.
---
Write a new `PolicyException` (kyverno.io/v2) in `policy-exceptions`:

- `exceptions: [{policyName: pod-security-baseline, ruleNames: [...]}]`. The
  DaemonSet is checked by the generated rule `autogen-disallow-host-path`, its
  Pods by `disallow-host-path`; list both, and nothing else.
- `match.any`: one entry for `kinds: [DaemonSet]` named `dcgm-exporter`, one
  for `kinds: [Pod]` named `dcgm-exporter-*`, both in `namespaces: [gpu-operator]`.

`kubectl explain policyexceptions.spec --api-version=kyverno.io/v2`
---
From the lesson directory:

    kubectl apply -f solution/exception.yaml
    kubectl apply -f manifests/dcgm-exporter.yaml
    kubectl -n gpu-operator get ds,pods -o wide
