Find out how the pods die:

    kubectl get pods
    kubectl describe pod -l batch.kubernetes.io/job-name=train | grep -A4 "Last State\|State:"
    kubectl get job train -o yaml | grep -A6 conditions

Exit code 137 is SIGKILL; the reason tells you who sent it.
---
OOMKilled: the process used more than the 768Mi limit. The limit is the budget
you must keep, so the memory has to come down. What in the Job decides how much
memory one training step needs? (The README has a table.)

Then: add `requests` (cpu and memory) and a CPU limit, and set
`OMP_NUM_THREADS` to the CPU limit. The log line `threads=N` shows what
PyTorch used.
---
    env:
    - {name: BATCH_SIZE, value: "64"}
    - name: OMP_NUM_THREADS
      valueFrom:
        resourceFieldRef: {resource: limits.cpu, divisor: "1"}
    resources:
      requests: {cpu: "1", memory: 512Mi}
      limits: {cpu: "2", memory: 768Mi}

Delete the Job and apply it again (a Job's pod template cannot be changed).
