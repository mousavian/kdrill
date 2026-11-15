# Graceful preemption: a last checkpoint on SIGTERM

## Concept

Spot instances are reclaimed with two minutes' notice, nodes are drained for
upgrades, low-priority pods are preempted. In each case Kubernetes stops the
pod politely: the kubelet sends **SIGTERM** to the container's main process,
waits **`terminationGracePeriodSeconds`** (default 30), then sends SIGKILL.
A training process that catches SIGTERM can finish the current step, write a
checkpoint, and exit; the next pod then loses nothing. Without it, the
replacement repeats everything since the last periodic checkpoint, and with
expensive checkpoints written every hour that is up to an hour of the whole
cluster's work.

Two details decide whether that works:

- **Who is PID 1.** The signal goes to the container's PID 1 only. With
  `command: [sh, -c, "setup; train"]` PID 1 is the shell. A shell running as
  PID 1 has no SIGTERM handler, and the kernel does not apply default actions
  to PID 1, so the signal is simply dropped and `train` keeps running until
  SIGKILL. `exec train ...` makes `train` itself PID 1 (so does the exec form
  `command: [train]`); a tiny init (`tini`, `dumb-init`) forwards signals when a
  wrapper is unavoidable.
- **Enough grace.** The period must cover the step in progress plus writing
  the checkpoint, which for a large model can be minutes.

The course's `train` handles SIGTERM: it finishes the step, writes
`ckpt-<step>.pt` and logs `received SIGTERM ... stopping at step N: wrote
...`, then exits 143. `CKPT_WRITE_SECONDS` makes each checkpoint take that
long, standing in for a multi-gigabyte upload.

## The situation

PVC `checkpoints` exists. Job `train` (1200 steps, about 2 minutes) checkpoints
every 400 steps, each checkpoint takes 5 s, the command is a shell one-liner
and `terminationGracePeriodSeconds` is 3.

## Your task

Make an eviction lose no steps, keeping `STEPS=1200`, `CKPT_EVERY=400`,
`CKPT_WRITE_SECONDS=5` and the checkpoints on the PVC:

- `terminationGracePeriodSeconds` between 15 and 120;
- SIGTERM must reach `train`.

**`kdrill verify` evicts the training pod once** (Eviction API, as a drain
would) when the run is past step 100, waits for the replacement, and checks
`metrics.json` on the PVC: the evicted attempt ended `preempted`, and the next
attempt started at (or after) the step where the eviction happened.

## Useful commands

    kubectl logs -f job/train
    kubectl exec job/train -- cat /proc/1/cmdline | tr '\0' ' '
    kubectl get pods -l batch.kubernetes.io/job-name=train
    kubectl logs <evicted pod> | tail -n 3

The verify that evicts takes 15-30 s. If the eviction already happened with
a broken Job, re-create the Job and verify again once it is past step 100. A
re-created Job finds the old checkpoints on the PVC and continues from them;
`kdrill reset` starts from scratch.

## On a real cluster

AWS gives a spot instance two minutes, GCP 30 seconds; the node termination
handler or the cloud's graceful node shutdown turns the notice into pod
evictions. Large jobs checkpoint asynchronously (copy weights to host memory
fast, upload in the background) and set grace periods of several minutes.
Distributed jobs need every rank to agree to stop at the same step (this
course's script does an all-reduce of a stop flag every step).

## Read more

- https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination
- https://kubernetes.io/docs/concepts/scheduling-eviction/api-eviction/
- https://kubernetes.io/docs/concepts/cluster-administration/node-shutdown/
- https://github.com/krallin/tini
