    kubectl get pods -l batch.kubernetes.io/job-name=buggy
    kubectl get pod <a buggy pod> -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'
    kubectl explain job.spec.podFailurePolicy.rules

buggy's pods exit with the same code every time: retrying is pointless.
steady has `backoffLimit: 0`: one eviction and it is gone for good.
---
One `podFailurePolicy` serves both Jobs:

- rule 1: `action: FailJob`, `onExitCodes: {containerName: train, operator: In, values: [42]}`
- rule 2: `action: Ignore`, `onPodConditions: [{type: DisruptionTarget}]`

Add `backoffLimit` (3 at most), `activeDeadlineSeconds` (60-3600) and
`ttlSecondsAfterFinished` (300-86400). Keep `FAIL_AT_STEP` in buggy: the bug
is the point.
---
    kubectl delete job buggy steady
    kubectl apply -f solution/jobs.yaml
    kdrill verify     # evicts steady once; run it again when steady has finished
