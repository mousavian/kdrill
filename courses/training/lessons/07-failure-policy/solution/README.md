# Solution

From the lesson directory:

    kubectl delete job buggy steady
    kubectl apply -f solution/jobs.yaml
    kdrill verify        # evicts steady's pod once, then: verify again when steady completes

What happens:

- `buggy` exits 42 at step 50. The first rule (`FailJob` on exit code 42 in
  container `train`) marks the Job Failed at once, reason `PodFailurePolicy`,
  after one pod instead of seven (the default `backoffLimit` is 6, with
  exponential back-off between attempts: 10 s, 20 s, 40 s, ...).
- verify evicts `steady`'s pod through the Eviction API, as `kubectl drain`
  would. The pod gets the condition `DisruptionTarget` before it is stopped;
  the `Ignore` rule means the failure is not counted against `backoffLimit: 0`
  and the Job simply creates a new pod (`status.failed` stays 0). Without the
  rule, `backoffLimit: 0` would fail the whole Job on the first drain.
- `activeDeadlineSeconds` caps the Job's total run time (all retries
  included); `ttlSecondsAfterFinished` lets the TTL controller delete the Job
  and its pods after it ends, so finished Jobs do not pile up.

Rules are checked in order and the first match wins; failures that match no
rule are counted against `backoffLimit` as usual. `podFailurePolicy` needs
`restartPolicy: Never`, and Job specs are immutable, hence delete and apply.
