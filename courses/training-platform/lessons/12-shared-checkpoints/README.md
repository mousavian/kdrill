# One checkpoint volume for all workers

## Concept

A distributed job's workers all need the same files: the dataset, and the
checkpoint they resume from. A PersistentVolumeClaim's **access mode** says
how many consumers may mount it:

| mode | who can mount it read-write |
|---|---|
| `ReadWriteOncePod` (RWOP) | one pod in the whole cluster |
| `ReadWriteOnce` (RWO) | pods on one node (any number of them) |
| `ReadWriteMany` (RWX) | pods on any number of nodes |
| `ReadOnlyMany` (ROX) | any number of nodes, read-only |

What a StorageClass supports depends on the storage behind it: block devices
(cloud disks, `local-path`) are RWO or RWOP, network filesystems (NFS,
CephFS, EFS, Filestore, Lustre) offer RWX. RWOP is a good guard against two
writers on one volume, but it also blocks the second worker of a training
run, which then stays **Pending**, and since every worker waits for all the
others at the rendezvous, the whole job stops.

Even with a shared volume, **only rank 0 writes** checkpoints: the model
copies are identical after every all-reduce, so one writer is enough, and two
would race on the same files. Every rank **reads** the checkpoint on resume,
so all of them need the volume (or the same bucket). A PVC's access modes are
immutable; changing them means a new claim (and, for local storage, losing
its data).

## The situation

The headless Service `workers` exists. Job `ddp` (2 workers, 400 steps,
checkpoint every 100 to `/ckpt`) mounts the PVC `checkpoints`, which was
created `ReadWriteOncePod`. One worker runs, the other is Pending.

## Your task

- PVC `checkpoints` with an access mode that more than one pod can use.
- Job `ddp` still with 2 workers (Indexed, completions 2, parallelism 2,
  `WORLD_SIZE=2`), `STEPS=400`, `CKPT_EVERY=100`, every worker mounting
  `checkpoints` at `/ckpt`.
- It completes; on the volume, `metrics.json` shows `done` at step 400 with
  `world_size` 2, and the newest checkpoint is from step 400.

## Useful commands

    kubectl get pods,pvc
    kubectl describe pod -l batch.kubernetes.io/job-completion-index=1 | tail -n 5
    kubectl explain pvc.spec.accessModes
    kubectl get storageclass local-path -o yaml

The run takes 30-60 seconds once both workers start.

## On a real cluster

The lab has one node, so `ReadWriteOnce` works for both workers. On a real
cluster they run on different nodes: an RWO disk can be attached to only one
of them, and the second worker would be stuck in `ContainerCreating` with a
`Multi-Attach error`. Use an RWX filesystem or object storage for checkpoints
(lesson 09), and node-local SSD only for caches. JobSet's
`volumeClaimPolicies` and StatefulSet's `volumeClaimTemplates` create one
claim per worker when each needs its own scratch volume.

## Read more

- https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes
- https://kubernetes.io/blog/2023/12/18/read-write-once-pod-access-mode-ga/
- https://kubernetes.io/docs/concepts/storage/persistent-volumes/#storage-object-in-use-protection
- https://docs.pytorch.org/tutorials/intermediate/ddp_tutorial.html#save-and-load-checkpoints
