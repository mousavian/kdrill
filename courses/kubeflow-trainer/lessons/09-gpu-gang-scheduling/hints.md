Look at where the four pods are, what each Pending pod says, and what the GPUs are doing:

    kubectl get trainjobs,pods -o wide
    kubectl describe pod -l jobset.sigs.k8s.io/jobset-name=llama | grep -A6 Events
    kubectl get nodes -l type=kwok -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu
---
Nothing in the scheduler knows that the two pods of a TrainJob belong together, so it placed one pod of each job and
left both jobs unable to start. Admission has to happen for the whole TrainJob at once: Kueue, which the
cluster has, does exactly that for workloads carrying `kueue.x-k8s.io/queue-name`. A running job cannot be
adopted: delete both TrainJobs and create them again with the label (the LocalQueue is called `training`).
---
See solution/trainjobs.yaml:

    kubectl delete trainjob llama mistral
    kubectl apply -f solution/trainjobs.yaml
