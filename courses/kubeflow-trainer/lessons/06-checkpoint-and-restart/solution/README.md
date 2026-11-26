# Solution

From the lesson directory:

    kubectl apply -f solution/runtime.yaml
    kubectl delete trainjob flaky
    kubectl apply -f solution/trainjob.yaml
    kdrill verify            # about 40-50 s: run, crash at 300, restart, resume, finish

- The crash made the pod exit with code 42. The runtime's Job has `backoffLimit: 0`, so the Job failed at
  once, and a JobSet without a `failurePolicy` fails when one of its Jobs fails. The TrainJob mirrored that: a
  `Failed` condition.
- `failurePolicy.maxRestarts: 3` (a field of the JobSet spec, so it lives in the runtime's
  `spec.template.spec`) tells JobSet to delete and recreate **every** Job of the set when one fails, up to
  three times; `status.restarts` counts them. A restart is a new pod: whatever was in the old container
  is gone.
- What survives is only what was written outside the container. `CKPT_DIR=/ckpt` plus a PVC mounted
  there gives the new pod the old checkpoints, and `train` resumes from the newest one (step 300 here;
  its metrics file records a second run starting at 300). It also remembers on that volume that the planted
  crash already happened (`FAIL_ONCE`), so the replacement runs through step 300.
- The volume is the user's business, so it goes in the TrainJob: `spec.runtimePatches` adds volumes and mounts
  (and node selectors, tolerations, labels) to named replicated jobs without touching the runtime. Each entry
  belongs to one `manager`. The container named in a patch must exist in the runtime (`node`).
- `spec.trainer` and `runtimeRef` are immutable, and the TrainJob keeps a runtime snapshot, so
  both fixes needed a new TrainJob.
