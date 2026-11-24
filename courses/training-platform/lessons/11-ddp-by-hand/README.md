# Distributed training by hand: two pods, one model

## Concept

**Data-parallel** training (PyTorch DDP) runs one copy of the model per
worker. Each worker takes its own batch, computes gradients, and an
**all-reduce** averages the gradients across all workers before every
optimizer step, so the copies stay identical and the effective batch is the
sum of the per-worker batches. Each worker has a **rank** (0 .. world size-1);
rank 0 coordinates and usually does the logging and checkpointing.

To start, the workers must find each other. `torch.distributed` reads
`WORLD_SIZE`, `RANK`, `MASTER_ADDR` and `MASTER_PORT`: rank 0 opens a small
key-value store on `MASTER_ADDR:MASTER_PORT`, every rank registers there,
then they open direct connections to each other (gloo on CPU, NCCL on GPUs).
Nothing trains until **all** `WORLD_SIZE` workers have joined.

On Kubernetes that maps onto pieces you already know:

- an **Indexed Job** with `completions = parallelism = world size`: the index
  (`JOB_COMPLETION_INDEX`) is the rank, and the pod's hostname is
  `<job>-<index>`;
- a **headless Service** (`clusterIP: None`) plus `subdomain: <service>` in the
  pod template: each pod then gets a stable DNS name
  `<job>-<index>.<service>`, so `MASTER_ADDR` can be `ddp-0.<service>` before
  anyone knows the pod's IP.

The course's `train` uses `JOB_COMPLETION_INDEX` as the rank when
`WORLD_SIZE` is above 1, waits up to `DIST_TIMEOUT` seconds for
`MASTER_ADDR` to resolve and for all workers to join, and logs
`all 2 workers connected`.

## The situation

PVC `results` exists. Job `ddp` is a 2-worker Indexed Job (300 steps, batch 16
per worker) with `MASTER_ADDR=ddp-0.workers`. There is no Service, and the pod
template says `subdomain: worker`. Both workers wait.

## Your task

- A headless Service `workers` that selects the Job's pods.
- Job `ddp` with `subdomain: workers`, still Indexed with 2 completions, 2 in
  parallel, `WORLD_SIZE=2` and `STEPS=300`.
- It completes; `results/metrics.json` shows status `done` at step 300 with
  `world_size` 2, two different pods, and a loss below 2.9.

## Useful commands

    kubectl logs -l batch.kubernetes.io/job-name=ddp --prefix
    kubectl get pods -o wide -L batch.kubernetes.io/job-completion-index
    kubectl run dns --rm -it --restart=Never --image=kdrill.local/ml-tiny:0.1.0 -- getent hosts ddp-0.workers
    kubectl explain pod.spec.subdomain

The run takes 30-60 seconds once both workers are connected.

## On a real cluster

The same pattern runs multi-node GPU training: one pod per node with 8 GPUs,
`torchrun --nnodes=N --nproc-per-node=8` inside, NCCL over InfiniBand or
EFA, and `MASTER_ADDR` pointing at rank 0's DNS name. Writing the Service and
the environment by hand is error-prone, which is why JobSet (lesson 14), the
Kubeflow Trainer and LeaderWorkerSet generate them.

## Read more

- https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-hostname-and-subdomain-field
- https://kubernetes.io/docs/concepts/services-networking/service/#headless-services
- https://kubernetes.io/docs/concepts/workloads/controllers/job/#completion-mode
- https://docs.pytorch.org/docs/stable/distributed.html#environment-variable-initialization
- https://docs.pytorch.org/tutorials/intermediate/ddp_tutorial.html
