# Mutate existing resources: propagate a namespace label to its Deployments

## Concept

A normal mutate rule changes the object *in the request*. A
**mutate-existing** rule changes *other, already stored* objects when a
trigger request arrives:

    rules:
    - match:                      # the trigger
        any:
        - resources: {kinds: [Namespace]}
      mutate:
        targets:                  # what gets patched
        - apiVersion: apps/v1
          kind: Deployment
          namespace: "{{ request.object.metadata.name }}"
        patchStrategicMerge:
          metadata:
            labels:
              team: "{{ request.object.metadata.labels.team }}"

In the patch, `request.object` is the trigger and `target` is the object
being patched. Targets can be narrowed by name, selector or preconditions.

It's asynchronous, like generate. The admission controller records an
**UpdateRequest**; the **background controller** fetches each target and
patches it with its own ServiceAccount, so it needs RBAC (`update`,
`patch`) for those kinds. The trigger request itself is never blocked. If
patching fails, you find out from the UpdateRequest and the controller logs.

A rule like this fires only when a trigger object is created or updated.
`spec.mutateExistingOnPolicyUpdate: true` additionally runs it for every
existing trigger when the policy is created or changed. That's how you
bring the current state in line.

JMESPath detail: keys containing `-` or `.` must be quoted, e.g.
`labels."cost-center"`. Kyverno validates variables when you apply a
policy and refuses broken ones.

Typical uses: propagate labels or annotations (cost allocation for GPU
spend), restart workloads when a Secret rotates (patch a template
annotation), or add something to resources that predate the policy.

## The situation

Finance wants GPU spend per cost center. Namespaces `research`
(`cost-center=cc-1001`) and `inference` (`cost-center=cc-2002`) run
Deployments and a StatefulSet; `sandbox` has no cost center. The ClusterPolicy
`propagate-cost-center` was applied, but none of the workloads are labelled.

## Your task

Fix `propagate-cost-center` (keep the name) so that:

- every Deployment **and StatefulSet** in a namespace with a `cost-center`
  label carries the label `cost-center` with the namespace's value,
  including the ones that already exist (no need to touch the namespaces);
- when a namespace's `cost-center` label changes, its workloads follow
  (verify changes `research` to `cc-1001-probe` and back);
- workloads in namespaces without the label are not labelled.

Only labels on the workload objects change: no Pod template changes, no
rollouts (every workload stays at `metadata.generation: 1`). Don't delete
or re-create the workloads.

## Useful commands

    kubectl get deploy,sts -A -L cost-center | grep -v kube-system
    kubectl -n kyverno get updaterequests
    kubectl -n kyverno logs deploy/kyverno-background-controller --tail=20
    kubectl explain clusterpolicy.spec.rules.mutate.targets

When you think you're done: `kdrill verify`

## On a real cluster

The background controller needs RBAC for every kind it patches. kdrill's
Kyverno install grants Deployments and StatefulSets already; on your
cluster you'd add an aggregated ClusterRole (label
`rbac.kyverno.io/aggregate-to-background-controller: "true"`) or set the
chart's `backgroundController.rbac.clusterRole.extraResources`.

## Read more

- https://kyverno.io/docs/policy-types/cluster-policy/mutate/#mutate-existing-resources
- https://kyverno.io/docs/policy-types/cluster-policy/variables/
- https://kyverno.io/docs/installation/customization/
