# Cap a NodePool with limits

## Concept

Karpenter will happily buy whatever the pending pods need. `spec.limits` on
a NodePool is the brake: a ceiling on the **total** resources of all nodes
the pool owns.

    limits:
      cpu: "100"
      memory: 400Gi
      nvidia.com/gpu: "8"

How it works:

- Karpenter keeps a running total per pool in `status.resources` (summed
  node **capacity**, not pod requests: a 16-vCPU node counts 16 even if it
  runs one small pod).
- Before launching, it drops every instance type that would push the total
  over a limit. If nothing is left, the pods stay Pending with the event
  `all available instance types exceed limits for nodepool`.
- Any resource name can be limited, including extended resources. A limit of
  `nvidia.com/gpu: "0"` removes every GPU instance type from the pool without
  touching its requirements.
- Limits only gate **new** launches. Lowering a limit below current usage
  removes nothing; existing nodes stay until consolidation, expiry or you
  delete them.
- Limits are per NodePool. Another pool (later lessons) may still provision.

Limits are a budget guard, not a scheduling tool: with a pool at its limit,
an important workload waits just like an unimportant one. They're your
defence against a runaway HPA, a mistaken `replicas: 500`, or a job that
quietly requests a GPU.

## The situation

NodePool `default` (amd64, on-demand, any family **including GPU
instances**) still has `limits.cpu: 4` from a trial. In namespace `web`:
- `web` (6 × 1 CPU, 2 GiB): 3 Running on one 4-vCPU node, 3 Pending.
- `ml-batch` (1 pod, 1 `nvidia.com/gpu`): an unapproved experiment, Pending
  only because the CPU limit is exhausted.

## Your task

Set the approved budget on NodePool `default`: **16 CPU, 64Gi memory, 0
`nvidia.com/gpu`**.

Result: all 6 `web` pods Running; `ml-batch` still Pending; no GPU node
exists; the pool's nodes total at most 16 CPUs.

Rules: don't change the requirements; don't change, scale or delete either
Deployment; don't create nodes yourself.

Order matters: raise the CPU limit without the GPU limit and Karpenter
immediately buys a GPU instance for `ml-batch` (and packs `web` pods onto
it). If that happens, add the GPU limit and remove that node with
`kubectl delete nodeclaim <name>`. New capacity appears within ~5 s.

## Useful commands

    kubectl get nodepool default -o jsonpath='{.status.resources}{"\n"}'
    kubectl -n web describe pod -l app=ml-batch | tail -4
    kubectl get nodeclaims
    kubectl explain nodepool.spec.limits
    kubectl -n karpenter logs deploy/karpenter | grep -i limit

When you think you're done: `kdrill verify`

## On a real cluster

Same behaviour on AWS. kdrill patches the KWOK provider so a fake node
reports its instance type's full capacity (upstream KWOK reports only the
requests that triggered it, which would make limits count pod requests).
Limits count resources, not money: a pool capped at 16 CPUs can still be
16 CPUs of an expensive family. Pair limits with requirements, and with
cloud budgets and alerts for spend.

## Read more

- https://karpenter.sh/docs/concepts/nodepools/#speclimits
- https://karpenter.sh/docs/troubleshooting/
