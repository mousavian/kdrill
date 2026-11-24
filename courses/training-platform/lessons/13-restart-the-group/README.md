# When one worker goes: restart the whole group

## Concept

Data-parallel workers are **all or nothing**. Every step ends in an
all-reduce that needs every rank, so if one worker disappears the others
cannot continue: they block in the collective until a timeout, or fail as
soon as the connection drops. A replacement for the lost worker cannot simply
join the running group either; with the usual static setup the group was
formed once at the rendezvous. Recovery means **restarting all workers** and
resuming everyone from the last shared checkpoint.

An Indexed Job gives you the pieces. When a worker pod fails, the Job creates
a new pod for that index, with the same hostname and DNS name, so a new
rendezvous can happen. What remains is accounting: in a two-worker run one
eviction produces **two** failed pods (the evicted worker, and its peer that
had to stop), and `backoffLimit` counts both. `backoffLimit: 0` is a sensible
"never retry a crash" setting, but then every node drain kills the job.

`podFailurePolicy` separates the cases (lesson 07): `Ignore` the pod that has
the `DisruptionTarget` condition, and `Ignore` the peer by the exit code the
training program uses for "my group stopped". Real crashes still fail the Job.
The course's `train` exits **143** in the worker that received SIGTERM, after
rank 0 has written a checkpoint, and **75** in workers that stopped because a
peer went away.

## The situation

The headless Service `workers` and a `ReadWriteOnce` PVC `checkpoints` exist.
Job `ddp` is a 2-worker Indexed Job (1500 steps, about 1-2 minutes,
checkpoint every 100) with `backoffLimit: 0` and no failure policy.

## Your task

Keep 2 workers, `backoffLimit: 0`, `STEPS=1500`, `CKPT_EVERY=100` and the
checkpoints on the PVC, and add a `podFailurePolicy` so that:

- an evicted worker (`DisruptionTarget`) is not counted;
- a worker that exits 75 because its peer left is not counted.

**`kdrill verify` evicts worker 1 once** while the run is past step 150, then
checks: the Job did not fail, `status.failed` is 0, a new attempt with both
workers resumed from the eviction step (`metrics.json` on the PVC), and,
when you verify again later, that the Job completed.

## Useful commands

    kubectl logs -f -l batch.kubernetes.io/job-name=ddp --prefix
    kubectl get pods -l batch.kubernetes.io/job-name=ddp -L batch.kubernetes.io/job-completion-index
    kubectl get job ddp -o jsonpath='{.status}'
    kubectl get events --sort-by=.lastTimestamp | tail

The evicting verify takes 20-40 s (both workers stop, restart and reconnect).

## On a real cluster

`torchrun` adds an elastic agent per node that restarts all local workers
when one fails (`--max-restarts`) and re-runs the rendezvous; frameworks like
JobSet (next lesson), the Kubeflow Trainer and LeaderWorkerSet restart whole
groups as a policy. On GPUs the cost of a group restart is large (reload
checkpoint, re-warm NCCL), so teams also detect stuck collectives quickly
(NCCL timeouts, watchdogs) instead of waiting 30 minutes for the default.

## Read more

- https://kubernetes.io/docs/concepts/workloads/controllers/job/#pod-failure-policy
- https://kubernetes.io/docs/concepts/workloads/controllers/job/#backoff-limit-per-index
- https://docs.pytorch.org/docs/stable/elastic/run.html
- https://docs.pytorch.org/docs/stable/distributed.html#torch.distributed.init_process_group
