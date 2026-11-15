# JobSet: the worker group as one object

## Concept

The last three lessons assembled a distributed run from parts: an Indexed
Job, a headless Service, a `subdomain`, environment variables, and a
podFailurePolicy that turns "one worker left" into "replace everyone".
**JobSet** (a Kubernetes SIG project) packages that pattern into one API
object:

- `replicatedJobs`: a list of Job templates, each created `replicas` times
  (e.g. one `driver` Job and one `workers` Job, or 4 worker Jobs of 8 pods
  for 4 slices);
- `network.enableDNSHostnames`: JobSet creates a headless Service named after
  the JobSet (or `network.subdomain`) and sets every pod's subdomain, so pods
  are reachable as `<jobset>-<replicatedJob>-<job index>-<pod index>.<jobset>`;
- `failurePolicy`: when any child Job fails, **restart the whole JobSet**
  (delete and recreate all Jobs) up to `maxRestarts` times, counted in
  `status.restarts`; `rules` can instead fail at once or restart a single Job
  depending on the Job's failure reason;
- `successPolicy`: complete when `All` (or `Any`) Jobs of the listed
  replicated jobs have completed;
- `startupPolicy` (`InOrder` starts a leader first), `suspend` and Kueue
  integration (Part D) for queueing the set as one unit.

The child Jobs are ordinary Jobs; set `backoffLimit: 0` in them so that a
failure is handed straight to the JobSet's policy.

## The situation

PVC `checkpoints` (ReadWriteOnce) exists. JobSet `ddp` has one replicated job
`workers`: one Indexed Job with 2 pods (1500 steps, checkpoint every 100,
`backoffLimit: 0`). Its `MASTER_ADDR` is still `ddp-0.workers` from lesson 11,
and it has no failure policy.

## Your task

JobSet `ddp`, still one Indexed Job of 2 workers (`WORLD_SIZE=2`),
`STEPS=1500`, `CKPT_EVERY=100`, checkpoints on the PVC, child
`backoffLimit: 0`:

- `MASTER_ADDR` is rank 0's JobSet DNS name;
- `failurePolicy.maxRestarts` between 1 and 5.

**`kdrill verify` evicts worker 1 once** when the run is past step 150, then
checks that the JobSet did not fail, restarted (`status.restarts` at least 1),
that the restarted workers resumed from the eviction step with 2 workers, and
(verify again later) that the JobSet completed.

## Useful commands

    kubectl get jobset,jobs,pods,svc
    kubectl get jobset ddp -o jsonpath='{.status}'; echo
    kubectl logs -f -l jobset.sigs.k8s.io/jobset-name=ddp --prefix
    kubectl explain jobset.spec.failurePolicy

The run takes about 1-2 minutes, plus 20-40 s for the restart.

## On a real cluster

JobSet is the building block under several higher-level APIs (the Kubeflow
Trainer's TrainJob creates a JobSet), and is used directly for TPU multi-slice
and multi-node GPU training. Its `exclusive-topology` annotation places each
child Job in its own rack or slice, and a restart recreates every pod, so
large jobs pair it with fast checkpoint loading. Kueue admits a JobSet as one
workload (lesson 17). Ray users get the same group semantics from KubeRay: a
`RayJob` starts a Ray cluster (head plus workers) for one training job and
tears it down afterwards, and Kueue can queue it as one unit too.

## Read more

- https://jobset.sigs.k8s.io/docs/overview/
- https://jobset.sigs.k8s.io/docs/concepts/
- https://jobset.sigs.k8s.io/docs/installation/
- https://jobset.sigs.k8s.io/docs/tasks/
