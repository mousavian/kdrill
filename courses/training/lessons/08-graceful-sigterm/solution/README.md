# Solution

From the lesson directory:

    kubectl delete job train
    kubectl apply -f solution/train.yaml
    # after the log shows step 100 or later:
    kdrill verify

Two things kept the final checkpoint from being written:

1. **The shell was PID 1.** `sh -c 'echo ...; train ...'` runs `train` as a
   child of `sh`. The kubelet sends SIGTERM to PID 1 only, and a shell running
   as PID 1 has no handler for it, so the kernel drops the signal: `train`
   never knew it was being stopped. `exec train ...` replaces the shell with
   `train` (alternatively: `command: [train]` with the arguments in `args`).
2. **3 seconds of grace.** After SIGTERM the kubelet waits
   `terminationGracePeriodSeconds`, then sends SIGKILL. The trainer needs to
   finish its current step and write a checkpoint that takes 5 s here; 30 s
   is comfortable (the default is also 30).

With both fixed, the log of the evicted pod ends with
`received SIGTERM ... stopping at step N: wrote ckpt-00000N.pt` (exit 143),
and the next pod logs `resumed from ckpt-00000N.pt at step N`.
