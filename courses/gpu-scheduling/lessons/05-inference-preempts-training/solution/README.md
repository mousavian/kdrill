# Solution

Training runs at priority 1000. The new Deployments had no class, so they got
priority 0, and a pod can only preempt pods of *lower* priority.

    kubectl apply -f solution/      # from the lesson directory

That creates the two classes (`00-priorityclasses.yaml`) and sets them on the
Deployments (same as):

    kubectl create priorityclass inference-critical --value=100000
    kubectl create priorityclass eval-no-preempt --value=5000 --preemption-policy=Never
    kubectl patch deploy chat-inference --type merge -p '{"spec":{"template":{"spec":{"priorityClassName":"inference-critical"}}}}'
    kubectl patch deploy nightly-eval  --type merge -p '{"spec":{"template":{"spec":{"priorityClassName":"eval-no-preempt"}}}}'

What happens: each new `chat-inference` pod (100000) finds no free GPUs, so
the scheduler evicts one 4-GPU `pretrain` pod and nominates that node. The
`pretrain` ReplicaSet recreates the evicted pods; they wait as Pending (1000).
The new `nightly-eval` pod (5000, Never) is also Pending, but it is ahead of
those `pretrain` pods in the queue: when 4 GPUs free up it goes first, and it
never evicts anything.

Takeaways:
- Low-priority training + high-priority inference = full utilisation without
  making inference wait.
- `preemptionPolicy: Never` = "jump the queue, don't push anyone out".
- Use a few clear tiers. Never make a preempting class `globalDefault`.
