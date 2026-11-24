    kubectl get jobset,jobs,pods,svc
    kubectl logs -l jobset.sigs.k8s.io/jobset-name=ddp --prefix | tail -n 4
    kubectl get pods -o custom-columns=NAME:.metadata.name,HOST:.spec.hostname,SUBDOMAIN:.spec.subdomain

What is rank 0's hostname now, and which Service gives it a DNS name?
---
- JobSet names the headless Service after the JobSet (`ddp`), and the pods
  `<jobset>-<replicatedJob>-<job index>-<pod index>`: rank 0 is `ddp-workers-0-0`,
  so `MASTER_ADDR=ddp-workers-0-0.ddp`.
- `spec.failurePolicy.maxRestarts` (try 3) makes a failed worker Job restart
  the whole set instead of failing it. `kubectl explain jobset.spec.failurePolicy`
---
See solution/jobset.yaml. A JobSet's replicated jobs cannot be edited, so:

    kubectl delete jobset ddp
    kubectl apply -f solution/jobset.yaml
