# Solution

From the lesson directory:

    kubectl apply -f solution/exception.yaml
    kubectl apply -f manifests/dcgm-exporter.yaml

The exception:

- lives in `policy-exceptions`, the only namespace this Kyverno honours
  (`--exceptionNamespace=policy-exceptions`). The attempt in `gpu-operator`
  is valid YAML and is ignored. Keeping exceptions in one namespace means
  RBAC on that namespace decides who may create them, and they are easy to
  review.
- names the rules exactly: `disallow-host-path` for Pods and
  `autogen-disallow-host-path` for the DaemonSet (the generated rule checks
  the Pod template at apply time). `disallow-privileged` stays in force.
- matches the DaemonSet by name and its Pods by `dcgm-exporter-*` in
  `gpu-operator` only.

What you get: the DaemonSet is admitted and its Pods run; a privileged
exporter Pod, a different hostPath Pod in the same namespace, or the same
Pod name elsewhere are all still rejected. Background reports show the
exempted resources as `skip`.

Notes:
- `kyverno.io/v2` PolicyException (for ClusterPolicy/Policy) prints a
  deprecation warning in 1.19, like ClusterPolicy itself. The CEL policy types
  use `policies.kyverno.io/v1` PolicyException, which matches with CEL
  expressions.
- `spec.conditions` can narrow further (e.g. only if a label is set), and
  `podSecurity` exempts individual Pod Security Standard controls for
  `validate.podSecurity` rules.
- Pod names are generated, so `names: ["dcgm-exporter-*"]` is a convenience,
  not a security boundary: anyone who can create Pods in `gpu-operator` could
  pick such a name. Combine with RBAC on the namespace.

Takeaways: exempt a workload, a rule, a namespace; never weaken the policy
for everyone. Keep exceptions where they get reviewed.
