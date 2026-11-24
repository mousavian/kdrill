# Generate: default NetworkPolicy, GPU quota and CA bundle per tenant namespace

## Concept

A **generate** rule creates *other* objects when a trigger object is created
or updated. The classic trigger is a Namespace: every new team namespace
gets its NetworkPolicy, ResourceQuota, RoleBindings and so on, without a
ticket.

    generate:
      apiVersion: v1
      kind: ResourceQuota
      name: gpu-quota
      namespace: "{{ request.object.metadata.name }}"
      synchronize: true
      data:                  # inline content ...
        spec: {hard: {requests.nvidia.com/gpu: "4"}}
      # clone: {namespace: platform, name: ca-bundle}   # ... or copy an existing object

- `data` embeds the object; `clone` copies an existing source object
  (`cloneList` copies several by label).
- `synchronize: true` keeps the generated ("downstream") object as the
  policy says. Kyverno re-creates it when deleted, reverts manual edits,
  and with `clone` copies changes from the source. With `false` it is
  created once and is then the namespace owner's to change.
- `generateExisting: true` also processes trigger objects that existed
  before the policy. Otherwise only future creates and updates count.

Generation is asynchronous. The admission controller records an
**UpdateRequest** in the `kyverno` namespace and the **background
controller** creates the objects with its own ServiceAccount. It must
therefore have RBAC for each kind it generates, and the objects show up a
moment after the namespace. When nothing appears, look at
`kubectl -n kyverno get updaterequests` and the background controller's
logs.

A ResourceQuota on `requests.nvidia.com/gpu` (see the gpu-scheduling
course) is a good per-tenant default: no namespace can grab the whole GPU
fleet by accident.

## The situation

Namespaces `team-a` and `team-b` carry a `tenant` label; `platform` holds the
ConfigMap `ca-bundle`. The ClusterPolicy `tenant-defaults` only has a
`default-deny` NetworkPolicy rule, without synchronize, and it hasn't done
anything for the two existing namespaces.

## Your task

Make `tenant-defaults` (keep the name) give every namespace with a `tenant`
label, both the existing `team-a`/`team-b` and any created later:

- NetworkPolicy `default-deny`: `podSelector: {}`, `policyTypes: [Ingress]`;
- ResourceQuota `gpu-quota` with `requests.nvidia.com/gpu: "4"`;
- ConfigMap `ca-bundle` with the same data as `platform/ca-bundle`.

All three stay in sync: a deleted NetworkPolicy comes back, a hand-edited
quota is reverted, and changes to `platform/ca-bundle` reach the copies.
Namespaces without a `tenant` label get none of them.

verify creates `kyv-probe-tenant` (`tenant=probe`) and `kyv-probe-plain`,
deletes/edits the generated objects there, and briefly adds a
`kdrill-probe` key to `platform/ca-bundle` (removed again afterwards).

## Useful commands

    kubectl get networkpolicy,resourcequota,configmap -n team-a
    kubectl -n kyverno get updaterequests
    kubectl -n kyverno logs deploy/kyverno-background-controller --tail=20
    kubectl explain clusterpolicy.spec.rules.generate

When you think you're done: `kdrill verify`

## Read more

- https://kyverno.io/docs/policy-types/cluster-policy/generate/
- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/concepts/policy/resource-quotas/
