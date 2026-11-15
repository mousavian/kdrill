Run `kdrill verify` while the job trains (it evicts worker 1), then:

    kubectl get job ddp -o jsonpath='{.status}'; echo
    kubectl get pods -l batch.kubernetes.io/job-name=ddp \
      -o custom-columns=NAME:.metadata.name,EXIT:.status.containerStatuses[0].state.terminated.exitCode
    kubectl get pod <evicted pod> -o jsonpath='{.status.conditions[?(@.type=="DisruptionTarget")]}'

Two pods failed, for two different reasons. Which of them should count against `backoffLimit: 0`?
---
You need a `podFailurePolicy` with two `Ignore` rules:

- one for the pod that was evicted: `onPodConditions: [{type: DisruptionTarget}]`;
- one for the worker that stopped because its peer left: `train` exits 75 then
  (`onExitCodes`, container `train`, operator `In`).

Keep `backoffLimit: 0`. Re-create the Job.
---
See solution/ddp.yaml:

    kubectl delete job ddp
    kubectl apply -f solution/ddp.yaml
    kdrill verify   # once past step 150; again when the Job completes
