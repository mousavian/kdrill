# Size it: memory, CPU and threads

## Concept

A training process has a memory profile set mostly by its configuration: the
model's weights and optimizer state are fixed, but the **activations** kept for
the backward pass grow with batch size × sequence length × layers. For this
course's tiny model:

| batch size | peak RSS |
|---|---|
| 32 | ~400 MB |
| 64 | ~450 MB |
| 128 | ~550 MB |
| 512 | ~1.1 GB |

(About 230 MB of that is PyTorch itself.) When a container goes over its
**memory limit**, the kernel's OOM killer ends it with SIGKILL: the pod shows
`Reason: OOMKilled`, `Exit Code: 137`, no Python traceback, often nothing in
the log at all. A Job then retries and dies the same way: an OOM caused by the
configuration is not transient.

**Requests** are what the scheduler reserves on a node; **limits** are what the
kernel enforces. For training, set the memory request close to the real peak
(so the node is not overcommitted) and the limit a little above it. CPU limits
are enforced by throttling (CFS quota), not by killing.

Threads are the second trap. PyTorch (OpenMP, MKL, oneDNN) starts one thread per
core it **sees**, and a container sees all of the node's cores, whatever its
CPU limit. Eight threads in a 2-CPU quota spend most of each period throttled
and run slower than two. Set `OMP_NUM_THREADS` (or `torch.set_num_threads`) to
the CPU limit; the downward API (`resourceFieldRef: limits.cpu`) does it from
the pod spec, so the two cannot drift apart. The training script prints
`threads=N` at start (and `cpu_limit=M` when it can read the container's
cgroup, warning when the two disagree).

## The situation

Job `train` (300 steps, seed 1) was given `BATCH_SIZE=512` to "train faster",
a memory limit of 768Mi and nothing else. Its pods keep dying.

## Your task

Job `train` completes all 300 steps with a final loss below 2.9, and:

- the memory limit stays **768Mi** (the budget): make the run fit in it;
- no pod of the Job was OOMKilled;
- memory request between 384Mi and the limit; a CPU request and a CPU limit
  (at most 2 cores);
- the number of PyTorch threads, logged as `threads=N`, equals the Job's CPU
  limit rounded up to whole cores.

A Job's pod template cannot be edited: delete the Job and apply it again.

## Useful commands

    kubectl get pods
    kubectl describe pod -l batch.kubernetes.io/job-name=train
    kubectl get pod -l batch.kubernetes.io/job-name=train -o jsonpath='{.items[*].status.containerStatuses[*].state.terminated.reason}'
    kubectl logs job/train | head -n 3
    kubectl explain pod.spec.containers.env.valueFrom.resourceFieldRef

A fixed run takes 20-40 seconds.

## On a real cluster

On GPUs the same trade-off is made per GPU: `CUDA out of memory` is a Python
exception (the process can log it), while host-memory overruns still end in
OOMKilled. Real jobs fix batch size per device and reach a larger effective
batch with gradient accumulation or more GPUs. GPU nodes are usually given
`requests == limits` (Guaranteed QoS) so training pods are the last to be
evicted, and data loader workers (`num_workers`) need CPU and shared memory
(`/dev/shm` as a memory-backed emptyDir) on top.

## Read more

- https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/
- https://kubernetes.io/docs/tasks/inject-data-application/environment-variable-expose-pod-information/
- https://docs.pytorch.org/docs/stable/notes/cpu_threading_torchscript_inference.html
