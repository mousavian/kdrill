# Solution

From the lesson directory:

    kubectl delete trainjob tuned
    kubectl apply -f solution/trainjob.yaml
    kdrill verify            # about 15-20 s for the run

- The first version set `STEPS=300` and `SEED=11` as environment variables. `train` reads its
  options from flags *and* environment variables, and **a flag wins**: the runtime's own
  `--steps 1200 --seed 1` were on the command line, so the variables were ignored.
- `spec.trainer.args` replaces the runtime's `args` as a whole (the runtime's `--log-every 100`
  is gone too, which is why the solution repeats `--log-every`). `spec.trainer.env` is merged:
  the runtime's `OMP_NUM_THREADS=1` is still in the pod next to `RUN_LABEL`.
  `resourcesPerNode` is merged on top of the runtime's requests and limits.
- `spec.trainer` is immutable after creation, so changing it means deleting and re-creating the
  TrainJob (the JobSet and the pod are replaced with it).
- Environment variables used by the PyTorch policy (`PET_NNODES`, `PET_NPROC_PER_NODE`,
  `PET_NODE_RANK`, `PET_MASTER_ADDR`, `PET_MASTER_PORT`) are reserved: a TrainJob that sets them is
  rejected (try it).
