# Serving and training on shared GPUs: priority and preemption

Fake pods on a fake GPU node (**no request is ever served**; the scheduler is real).

## Concept

GPUs are too expensive to leave idle, so inference and training often share them:
training soaks up whatever serving does not use. The conflict arrives with a traffic
spike, when serving wants GPUs that training holds. The cluster must know who wins.

The scheduler's tool is **priority**: a pod's `priorityClassName` gives it an integer
priority. A Pending pod of higher priority can **preempt** lower-priority pods on
a node, evicting just enough of them to fit. Serving gets the high class; training the
low one, and training must survive being evicted, which means checkpointing and an
automatic resume (a Job or Deployment recreates the pod, which waits Pending until GPUs free
up again). Further knobs: `preemptionPolicy: Never` (a pod that gets scheduling priority
but never evicts anybody; good for batch evaluation) and PodDisruptionBudgets (which preemption
only *tries* to honour: priority beats a PDB).

Do not make a class `globalDefault` unless you mean it: it applies to every pod
created without one. For quotas, fair sharing between teams, borrowing of idle
capacity and gang scheduling of multi-pod training jobs, priority is not enough: use Kueue
(gpu-scheduling course, lessons 05 to 09).

## The situation

One fake node with 8 H100 GPUs. `finetune` (2 replicas, 2 GPUs each) and `chat` (2 replicas, 2 GPUs
each) fill it. A traffic burst raised `chat` to 3 replicas: 6 GPUs for chat plus 4 for finetune is 10
on an 8-GPU node, so the third chat pod is Pending. All pods have priority 0.

## Your task

Without changing replica counts or GPU requests:

- create PriorityClasses and set `priorityClassName` on both Deployments, with chat's
  value higher than finetune's, neither one `globalDefault`;
- the third chat replica becomes Running by preempting exactly one finetune pod: chat 3 Running,
  finetune 1 Running and 1 Pending, and a `Preempted` event for a finetune pod exists.

## Useful commands

    kubectl get pods -o wide
    kubectl get priorityclass
    kubectl get events --field-selector reason=Preempted
    kubectl explain priorityclass

When you think you're done: `kdrill verify`

## On a real cluster

Combine with Kueue (queues, quotas, borrowing), checkpoints to shared storage with the
trainer's own resume logic (Kubeflow Trainer, torchrun elastic), and an autoscaler for the serving side.
System pods already use `system-cluster-critical` and `system-node-critical`; never put workloads above them.

## Read more

- https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/
- https://kueue.sigs.k8s.io/docs/concepts/preemption/
- https://kubernetes.io/docs/tasks/administer-cluster/guaranteed-scheduling-critical-addon-pods/
