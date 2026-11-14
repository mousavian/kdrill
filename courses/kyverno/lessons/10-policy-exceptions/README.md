# PolicyExceptions: a narrow, reviewed exemption

## Concept

Every cluster has legitimate exceptions: GPU device plugins, CNI agents,
log collectors and monitoring exporters need host access that application
Pods never should. Excluding them inside the policy (`exclude:`) works, but
it mixes "the rule" with a growing list of special cases, and anyone who
edits the policy can widen it.

A **PolicyException** is a separate object that exempts specific resources
from specific rules:

    apiVersion: kyverno.io/v2
    kind: PolicyException
    metadata: {name: ..., namespace: policy-exceptions}
    spec:
      exceptions:
      - policyName: pod-security-baseline
        ruleNames: [disallow-host-path, autogen-disallow-host-path]
      match:
        any:
        - resources: {kinds: [Pod], namespaces: [gpu-operator], names: ["dcgm-exporter-*"]}

- `ruleNames` must name the exact rules, including autogen rules
  (`autogen-<rule>` for Deployments, DaemonSets and the like,
  `autogen-cronjob-<rule>`) when controllers are involved.
- `match` (and `exclude`, `conditions`) select what is exempted, as in a
  policy.
- Exempted resources are allowed and show as `skip` in reports.

Exceptions are a feature you switch on (`--enablePolicyException`), and you
should restrict where they may live (`--exceptionNamespace`). Then RBAC on
that one namespace decides who can grant exceptions, and a GitOps
repository for it gets the right reviewers.

The negation anchor `X(key)` in this lesson's policy means "this key must
not be present": `=(volumes): [{X(hostPath): "null"}]` forbids any volume
of type hostPath.

## The situation

The Enforce ClusterPolicy `pod-security-baseline` forbids hostPath volumes and
privileged containers everywhere. The GPU team needs the DCGM exporter
DaemonSet (`manifests/dcgm-exporter.yaml`) in `gpu-operator`, which mounts the
kubelet's pod-resources directory read-only. Someone already created a
PolicyException next to it in `gpu-operator`; the DaemonSet is still rejected.

## Your task

Without changing the policy (both rules stay Enforce, no `exclude`):

- create a PolicyException in namespace `policy-exceptions` that exempts
  only the DaemonSet `dcgm-exporter` and its Pods (`dcgm-exporter-*`) in
  `gpu-operator`, and only from the hostPath rule;
- apply `manifests/dcgm-exporter.yaml`: the DaemonSet runs a ready Pod on
  each worker node, still with its hostPath and not privileged.

Still rejected afterwards: a privileged `dcgm-exporter-*` Pod, another hostPath
Pod in `gpu-operator`, and a `dcgm-exporter-*` Pod in another namespace
(verify creates `kyv-probe-other`).

## Useful commands

    kubectl get policyexceptions -A
    kubectl explain policyexceptions.spec --api-version=kyverno.io/v2
    kubectl -n gpu-operator describe ds dcgm-exporter
    kubectl create --dry-run=server -f probes/other-pod.yaml -n gpu-operator

When you think you're done: `kdrill verify`

## Read more

- https://kyverno.io/docs/guides/exceptions/
- https://kyverno.io/docs/policy-types/cluster-policy/validate/#anchors
- https://kubernetes.io/docs/concepts/storage/volumes/#hostpath
