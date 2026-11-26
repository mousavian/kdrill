# Solution

From the lesson directory:

    kubectl apply -f solution/runtime.yaml
    kubectl delete trainjob ddp
    kubectl wait --for=delete pod -l jobset.sigs.k8s.io/jobset-name=ddp --timeout=60s
    kubectl apply -f manifests/trainjob.yaml
    kdrill verify            # about 30 s for the run

- Without a framework policy the controller's "plain ML" mode only sets the number of pods
  (`numNodes: 2` became one Indexed Job with 2 completions). Nothing tells the pods they belong
  together, so each one trained alone ("rank 0/1" in both logs).
- `mlPolicy.torch` makes the controller inject, into the trainer container of every node:
  `PET_NNODES` (2), `PET_NPROC_PER_NODE` (processes per node: the CPU request rounded up when no GPUs are
  requested, here 1; `auto` when they are), `PET_NODE_RANK` (the Job completion index: 0 or 1),
  `PET_MASTER_ADDR` (`ddp-node-0-0.ddp`: the DNS name JobSet gives rank 0, through the headless
  Service named after the TrainJob) and `PET_MASTER_PORT` (29500).
- `torchrun` understands exactly those `PET_*` variables, starts the script and gives it `RANK`,
  `WORLD_SIZE`, `MASTER_ADDR`, `MASTER_PORT`; the tiny `train` joins the group (CPU, gloo backend) and
  logs `all 2 workers connected`. Calling `train` directly, as the runtime did, ignores them.
- The old TrainJob kept a snapshot of the old runtime (a ConfigMap `ddp-runtime-snapshot`), so it
  had to be deleted and created again.

- Why the `kubectl wait`: the old TrainJob's pods stay `Terminating` for a few seconds, and the new TrainJob's pods
  have **the same names and DNS names** (`ddp-node-0-0.ddp`). A new rank that resolves the name too early can reach an old pod
  and fail when that pod dies. The lab's runtime sets `terminationGracePeriodSeconds: 3` to keep the window short;
  waiting for the old pods to disappear closes it. (On a real cluster, use a new name for every run.)
