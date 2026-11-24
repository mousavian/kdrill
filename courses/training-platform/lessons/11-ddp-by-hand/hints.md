    kubectl logs -l batch.kubernetes.io/job-name=ddp --prefix | tail
    kubectl get svc
    kubectl get pod -l batch.kubernetes.io/job-name=ddp -o jsonpath='{.items[*].spec.subdomain}'

The workers wait for `ddp-0.workers` to resolve. Who would create that DNS name?
---
A pod gets the DNS name `<hostname>.<subdomain>.<namespace>.svc.cluster.local`
when a **headless Service** (clusterIP: None) whose name equals the pod's
`subdomain` selects it. Indexed Job pods are named `<job>-<index>` and have
the label `batch.kubernetes.io/job-name`.
---
Create Service `workers` (clusterIP: None, selector batch.kubernetes.io/job-name: ddp,
port 29500, publishNotReadyAddresses: true), set `subdomain: workers` in the
Job's pod template, and re-create the Job:

    kubectl apply -f solution/workers-svc.yaml
    kubectl delete job ddp && kubectl apply -f solution/ddp.yaml
