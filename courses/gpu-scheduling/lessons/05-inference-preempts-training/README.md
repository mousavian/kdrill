# Inference preempts training, eval waits its turn

## Concept

GPU clusters usually run two kinds of work side by side:

- **Online inference**: user-facing, latency-sensitive, must get GPUs *now*.
- **Training and batch jobs**: long-running, but they checkpoint and can be
  restarted. Their job is to soak up whatever GPUs are idle.

Pod priority lets one fleet serve both. Training runs at a low priority and
fills the cluster. When inference needs GPUs, its higher priority lets the
scheduler **preempt** (evict) enough training pods to make room. The
training pods' controller recreates them, and they wait as Pending until GPUs
free up again. Put training at the bottom (`training-low` here), inference at
the top, and other tiers in between.

Not every important job should evict others. A **non-preempting** class
(`preemptionPolicy: Never`) gives pods a high priority for **queue order**:
when GPUs free up, they are scheduled before lower-priority pending pods. But
they never evict anything. That suits batch evaluation or data processing
that should run before training but isn't worth killing a 3-day training run
for.

Details that matter with GPUs:

- Preemption evicts **whole pods**, gracefully (`terminationGracePeriodSeconds`).
  Give training time to write a checkpoint, and make it resume on restart.
- The scheduler picks the node where evicting the fewest, lowest-priority pods
  makes room, and records it in the pending pod's
  `status.nominatedNodeName`.
- Priority is copied into each pod (`spec.priority`, `spec.preemptionPolicy`)
  **at creation**. A class's `value` and `preemptionPolicy` are immutable;
  to change them, delete and recreate the class, then recreate the pods.
- Preemption is per pod. A multi-pod training job can lose one worker and
  stall the rest; gang-aware tools (Kueue, lesson 09) preempt whole jobs.

## The situation

Two nodes with 8 H100s each. `pretrain` (4 pods × 4 GPUs, class
`training-low`, value 1000) uses all 16 GPUs. `chat-inference` (2 × 4 GPUs)
and `nightly-eval` (1 × 4 GPUs) were just deployed with no class, and both are
Pending.

## Your task

- Create PriorityClass `inference-critical`: value above 1000, not
  `globalDefault`, default preemption policy. Use it in `chat-inference`, and
  get both replicas Running.
- Create PriorityClass `eval-no-preempt`: value above 1000 but below
  `inference-critical`, `preemptionPolicy: Never`, not `globalDefault`. Use it
  in `nightly-eval`. Its pod must stay Pending (there are no free GPUs and it
  may not evict training), carrying priority > 1000 and policy `Never`.
- Final state for `pretrain`: 2 pods Running, 2 Pending.

Rules: don't touch `pretrain` (replicas, class, requests) or `training-low`;
keep every Deployment at 4 GPUs per pod; don't change the nodes.

## Useful commands

    kubectl get priorityclass
    kubectl get pods -o custom-columns=NAME:.metadata.name,PRIO:.spec.priority,POLICY:.spec.preemptionPolicy,NODE:.spec.nodeName,PHASE:.status.phase
    kubectl get events --sort-by=.lastTimestamp | grep -i preempt
    kubectl explain priorityclass.preemptionPolicy

When you think you're done: `kdrill verify`

## On a real cluster

Preemption works the same on real nodes. The difference is the cost: an
evicted training pod loses everything since its last checkpoint, and a GPU
pod may need minutes to start again (image pull, model load). Pair priority
with PodDisruptionBudgets for inference and with checkpointing for training.
Kueue's WorkloadPriorityClass lets you prioritise queued jobs without
changing pod priority.

## Read more

- https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/
- https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/#non-preempting-priority-class
