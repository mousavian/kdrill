# Failure policy: retry disruptions, fail fast on bugs

## Concept

A Job retries failed pods up to `backoffLimit` times (default 6), waiting
10 s, 20 s, 40 s, ... between attempts. That treats every failure the same,
and training jobs fail in two very different ways:

- **A bug or a bad configuration** (a shape mismatch, a NaN check, a missing
  file): the same code fails at the same step every time. Retrying wastes
  GPU-hours and delays the alert.
- **A disruption** (node drain, spot reclaim, preemption): nothing is wrong
  with the job; it should simply continue elsewhere, as often as needed,
  without using up its retry budget.

`spec.podFailurePolicy` tells the Job controller which is which. Each rule
matches a failed pod by its container **exit codes** (`onExitCodes`) or its
**pod conditions** (`onPodConditions`), and picks an action: `FailJob` (stop
now), `Ignore` (replace the pod without counting it), `Count` (the default
behaviour) or `FailIndex` (Indexed Jobs). Rules are checked in order; the
first match wins. A pod that was evicted, preempted or removed by the node
lifecycle gets the condition **`DisruptionTarget`** before it is stopped, which
is what an `Ignore` rule keys on. (A plain `kubectl delete pod` does not set
it.) The policy requires `restartPolicy: Never`.

Two more fields belong to every training Job: `activeDeadlineSeconds` caps the
total run time, retries included (a hung run does not hold resources
forever), and `ttlSecondsAfterFinished` deletes the finished Job and its pods
after a while.

The course's `train` exits **42** on a "bug" (`FAIL_AT_STEP`) and 143 when it
is stopped by SIGTERM.

## The situation

- Job `buggy` crashes at step 50 (exit 42), every time. It has the default
  `backoffLimit`.
- Job `steady` is a healthy 500-step run with `backoffLimit: 0` ("we never
  want retries").

## Your task

For **both** Jobs:

- a `podFailurePolicy` with a `FailJob` rule for exit code 42 and an `Ignore`
  rule for the `DisruptionTarget` pod condition;
- `backoffLimit` at most 3, `activeDeadlineSeconds` between 60 and 3600,
  `ttlSecondsAfterFinished` between 300 and 86400.

Then:

- `buggy` (keep `FAIL_AT_STEP=50`) fails with reason `PodFailurePolicy` after
  a single pod;
- `steady` survives an eviction: **verify evicts steady's running pod once**
  (through the Eviction API, like `kubectl drain`), and the Job must replace it
  without counting a failure (`status.failed` stays 0) and complete.

## Useful commands

    kubectl get jobs,pods
    kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'
    kubectl get pod <pod> -o jsonpath='{.status.conditions[?(@.type=="DisruptionTarget")]}'
    kubectl get job steady -o jsonpath='{.status.failed}'
    kubectl explain job.spec.podFailurePolicy

The first `kdrill verify` with steady running performs the eviction and takes
up to 10 s; steady then needs about a minute to finish. Verify again then.

## On a real cluster

Training frameworks give crashes distinct exit codes (or wrap the trainer in
a launcher that does), so `FailJob` / `Ignore` rules can tell bugs from
infrastructure. Combined with `backoffLimitPerIndex` (Indexed Jobs) and
checkpoints, a job keeps going through a dozen node drains a week and stops at
the first real bug. JobSet (lesson 14) adds the same idea for groups of Jobs.

## Read more

- https://kubernetes.io/docs/concepts/workloads/controllers/job/#pod-failure-policy
- https://kubernetes.io/docs/tasks/job/pod-failure-policy/
- https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-conditions
- https://kubernetes.io/docs/concepts/workloads/controllers/ttlafterfinished/
