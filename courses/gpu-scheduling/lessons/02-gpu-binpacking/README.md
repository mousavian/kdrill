# Bin-pack GPUs to stop fragmentation

## Concept

For each node that passes the filters, the scheduler computes a **score** and
picks the highest. The `NodeResourcesFit` plugin scores how full a node would
be after placing the pod, with one of three strategies:

- **LeastAllocated** (the default): emptier nodes score higher, so pods
  *spread*. Good for web services: one node failing hurts less.
- **MostAllocated**: fuller nodes score higher, so pods *pack*.
- **RequestedToCapacityRatio**: you draw the curve yourself (utilisation →
  score), e.g. "pack until 80 %, then spread".

Each strategy takes a list of resources and weights. The default profile only
scores `cpu` and `memory`, so it ignores GPUs completely.

For GPUs, spreading causes **fragmentation**. Six 1-GPU inference pods spread
over three 4-GPU nodes leave 2 free GPUs on every node, and a 4-GPU training
pod fits nowhere even though 6 GPUs are idle. A pod's GPUs must all come from
one node, so the free GPUs can't be added up.

A scheduler can run several **profiles**, each with its own `schedulerName`
and plugin config (a `KubeSchedulerConfiguration`). A pod picks one with
`spec.schedulerName`; the default is `default-scheduler`. In this cluster a
second kube-scheduler runs in `kube-system` with one profile, `gpu-binpack`:

    profiles:
    - schedulerName: gpu-binpack
      plugins:
        score:
          disabled: [{name: NodeResourcesBalancedAllocation}, {name: PodTopologySpread}]
      pluginConfig:
      - name: NodeResourcesFit
        args:
          scoringStrategy:
            type: MostAllocated
            resources: [{name: nvidia.com/gpu, weight: 10}, {name: cpu, weight: 1}, {name: memory, weight: 1}]

Packing decides only where *new* pods go. Pods that are already running stay
put until something recreates them.

## The situation

Three nodes with 4 L40S GPUs each. `chat` runs 6 one-GPU replicas, spread
2-2-2. The `finetune` pod needs 4 GPUs on one node and is Pending.

## Your task

Get `finetune` Running by having the `chat` pods scheduled by `gpu-binpack`.

Rules:
- `chat` sets `spec.template.spec.schedulerName: gpu-binpack`, keeps 6 replicas
  and 1 GPU per pod, and all its pods are Running.
- Don't pin `chat` by hand: no `nodeName`, `nodeSelector` or node affinity.
- `finetune` keeps one pod with 4 GPUs.
- Don't change the nodes or add any. No node may end up with more GPUs booked
  than it has.

## Useful commands

    kubectl get pods -o wide
    kubectl describe pod -l app=finetune
    kubectl describe node l40s-1 | grep -A8 'Allocated resources'
    kubectl -n kube-system get configmap gpu-binpack-scheduler -o yaml
    kubectl -n kube-system logs deploy/gpu-binpack-scheduler | tail

When you think you're done: `kdrill verify`

## On a real cluster

You can change the default profile instead of running a second scheduler: pass
a `KubeSchedulerConfiguration` with `--config` to kube-scheduler (on k3s:
`--kube-scheduler-arg=config=/path`). Managed clusters vary: GKE has an
`optimize-utilization` autoscaling profile, and others need a second scheduler
like this one. Two schedulers sharing nodes can occasionally race for the same
free capacity; the kubelet then rejects one pod and it is recreated. KWOK
nodes have no kubelet, so here verify checks for overbooking itself.

## Read more

- https://kubernetes.io/docs/concepts/scheduling-eviction/resource-bin-packing/
- https://kubernetes.io/docs/reference/scheduling/config/
- https://kubernetes.io/docs/tasks/extend-kubernetes/configure-multiple-schedulers/
