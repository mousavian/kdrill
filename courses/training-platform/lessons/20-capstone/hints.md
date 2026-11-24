Start from what you see:

    kubectl get jobset,workloads,pods
    kubectl get jobset capstone -o jsonpath='{.status}'; echo
    kubectl logs -l jobset.sigs.k8s.io/jobset-name=capstone --prefix | grep -E "resumed|starting|crash|lost"

There are four faults: one about the queue, one about what happens after a
crash, one about where state lives, one about the result.
---
- Queue: the label goes on the JobSet's own metadata (lesson 17).
- After a crash: `spec.failurePolicy.maxRestarts` (lesson 14).
- State: the checkpoints (and the crash-once marker beside them) must survive
  a restart: the PVC `checkpoints`, mounted by both workers (lesson 12).
- Result: `MODEL_OUT=/models/capstone`, then run the sample Job (lesson 19).
Keep the FAIL_* variables.
---
See solution/capstone.yaml:

    kubectl delete jobset capstone
    kubectl apply -f solution/capstone.yaml
    kubectl wait jobset/capstone --for=condition=Completed --timeout=300s
    kubectl apply -f solution/sample.yaml
