`kubectl get pods -o wide`: each Job has 2 workers Running and 2 Pending, and
all 4 GPUs are taken. Distributed training needs every worker, so both jobs
are stuck forever. The scheduler places pods one by one and doesn't know they
belong together.
---
Kueue admits a whole Job only if its quota fits all of its pods, and keeps the
rest suspended with no pods. The queue is already there
(`kubectl get localqueue`). A Job opts in with the label
`kueue.x-k8s.io/queue-name`, and it has to be there when the Job is created.
---
    kubectl delete job llama-ft mistral-ft
    kubectl apply -f solution/jobs.yaml     # from the lesson directory

(or add `labels: {kueue.x-k8s.io/queue-name: training}` to both Jobs in
manifests/jobs.yaml and apply that).
