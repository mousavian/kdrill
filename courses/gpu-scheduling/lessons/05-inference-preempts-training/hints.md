Look at the priorities:

    kubectl get priorityclass
    kubectl get pods -o custom-columns=NAME:.metadata.name,PRIO:.spec.priority,POLICY:.spec.preemptionPolicy,NODE:.spec.nodeName,PHASE:.status.phase

Training runs at 1000 (`training-low`). Inference and eval have no class, so
they get priority 0: lower than training, so they can't preempt anything.
---
You need two classes. `inference-critical`: a high value with the default
`preemptionPolicy` (PreemptLowerPriority). `eval-no-preempt`: a value between
1000 and the inference value, with `preemptionPolicy: Never`, so it is ahead
of training in the scheduling queue but never evicts it.
---
    kubectl create priorityclass inference-critical --value=100000 --description="online inference"
    kubectl create priorityclass eval-no-preempt --value=5000 --preemption-policy=Never --description="batch eval, never preempts"
    kubectl patch deploy chat-inference --type merge -p '{"spec":{"template":{"spec":{"priorityClassName":"inference-critical"}}}}'
    kubectl patch deploy nightly-eval  --type merge -p '{"spec":{"template":{"spec":{"priorityClassName":"eval-no-preempt"}}}}'

(or `kubectl apply -f solution/` from the lesson directory).
