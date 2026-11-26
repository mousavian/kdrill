# A crash at step 300 - checkpoints and JobSet restarts

## Concept

Training runs fail: a node is drained, a pod is OOM-killed, a bug fires at step 300. What happens next is decided
in two places.

**Who restarts.** A TrainJob does not restart anything itself; its JobSet does. The runtime's JobSet spec can set
`failurePolicy`: with `maxRestarts: N`, when any child Job fails the JobSet deletes **all** its Jobs and creates
them again, N times at most (`status.restarts` counts them); `rules` can pick other actions per failure reason.
With the default (no policy) one failed Job fails the JobSet, and the TrainJob becomes `Failed`. Every pod of the
group is replaced, even those that were healthy: for multi-node training that is the right thing, since the
ranks must start together. The Job-level `backoffLimit` is a second, separate restart loop for single pods;
the runtimes in this course set it to 0 and let the JobSet decide.

**What survives.** A restart creates new containers with empty filesystems. Only a volume carries state over,
so the training must write checkpoints there and resume from the newest one (`train`: `CKPT_DIR`, `CKPT_EVERY`).
Where that volume comes from is the user's call, not the platform's, so a TrainJob adds it with
**`spec.runtimePatches`**: entries, each owned by a `manager` (a domain-prefixed name such as
`kdrill.dev/learner`; Kueue writes its own entry the same way), that add volumes, mounts, node selectors or
tolerations to named replicated jobs. Patches can only be changed while the TrainJob is suspended.

Terms to keep apart: *a TrainJob fails* (a `Failed` condition, final), *a JobSet restarts* (a new attempt of the
same TrainJob), *a pod is rescheduled* (the same Job).

## The situation

The PVC `checkpoints` and the platform's runtime `tiny-resume` exist. The TrainJob `flaky` (800 steps,
checkpoint every 50) has a planted crash: at step 300 the process exits with code 42, once (it remembers this
next to the checkpoints, on the volume if there is one). It has no checkpoint volume and the runtime does not
restart anything: it ends `Failed`.

## Your task

Fix the runtime (`tiny-resume`: restart the group after a failure, at most 3 times) and give a new TrainJob
`flaky` a checkpoint volume: the PVC `checkpoints` mounted at `/ckpt` through `runtimePatches`, with
`CKPT_DIR=/ckpt` in its environment. Keep the planted fault (the crash must still happen) and the other
settings.

`kdrill verify` checks the runtime's `failurePolicy.maxRestarts` (1 to 5); that the TrainJob is a new one, still
has `FAIL_AT_STEP=300`, `FAIL_ONCE=true` and `STEPS=800`, mounts the PVC `checkpoints` and that its JobSet is
owned by it; that the JobSet restarted (`status.restarts` at least 1) and the TrainJob **completed**; and, read
from the volume's `metrics.json`, that there were two attempts and the second **resumed from step 250 or later,
not from 0**. A run takes about 45 s; verify says where it is while it runs.

## Useful commands

    kubectl get trainjob,jobset,pods
    kubectl get trainjob flaky -o jsonpath='{.status.conditions}'; echo
    kubectl get jobset flaky -o jsonpath='{.status}'; echo
    kubectl get pods -o custom-columns=NAME:.metadata.name,EXIT:.status.containerStatuses[0].state.terminated.exitCode
    kubectl explain jobset.spec.failurePolicy            # same fields as in the runtime's template
    kubectl explain trainjob.spec.runtimePatches --recursive | head -60

## On a real cluster

Pair `maxRestarts` with fast checkpoint storage: every restart recreates every pod of a large job and reloads
the checkpoint on all of them. Use failure `rules` to treat kinds of failure differently (for example fail fast
on an application error with exit code 42, restart on a node failure). The checkpoint volume would be a
ReadWriteMany filesystem or object storage (training-platform 09), not a node-local volume. For GPU jobs, give
priority to jobs that already hold a checkpoint, and set `activeDeadlineSeconds` so that a crash loop cannot
run forever (next lesson).

## Read more

- https://jobset.sigs.k8s.io/docs/concepts/
- https://www.kubeflow.org/docs/components/trainer/operator-guides/runtime/
- https://www.kubeflow.org/docs/components/trainer/operator-guides/runtime-patches/
- https://pytorch.org/tutorials/recipes/distributed_checkpoint_recipe.html
