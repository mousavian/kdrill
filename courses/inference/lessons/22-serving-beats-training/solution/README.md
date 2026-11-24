# Solution

From the lesson directory:

    kubectl apply -f solution/priority.yaml
    kubectl patch deploy finetune --type=merge -p '{"spec":{"template":{"spec":{"priorityClassName":"training"}}}}'
    kubectl patch deploy chat --type=merge -p '{"spec":{"template":{"spec":{"priorityClassName":"serving"}}}}'

(Order: the training class goes onto the training pods first, then serving; both templates roll.)

Scheduler preemption: when a pod cannot be scheduled and a node would fit it if **lower-priority
pods were evicted**, the scheduler picks the node and victims that disturb least (lowest priorities, fewest
victims) and deletes them (event `Preempted`); the pending pod is then bound. Equal priorities never preempt. So
the pecking order is expressed with PriorityClasses: `serving` (100000) above `training` (1000).

What happens to the evicted training pod: its Deployment recreates it, it is Pending (no GPU) and waits,
which is only acceptable when training **checkpoints** and resumes (`--resume-from /ckpt/latest`):
an eviction costs the work since the last checkpoint. Also decide the reverse: a training pod
with a *high* priority could evict serving, which is why the serving class is higher and why
`preemptionPolicy: Never` exists for pods that should wait their turn without evicting others (batch evaluation).

Priority and preemption are a blunt tool: they act pod by pod and know nothing about teams or quotas. **Kueue**
adds queues, quotas, cohorts with borrowing and reclaim, and gang admission; it is covered in the
gpu-scheduling course (lessons 05 to 09), which pairs naturally with this one:
serving gets a guaranteed quota it may lend, training borrows idle serving GPUs, and gets preempted when serving
wants them back.
