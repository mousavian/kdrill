Watch the pod's last log lines when it is evicted (run `kdrill verify` while it
trains, then):

    kubectl logs <the evicted pod> | tail -n 3      # or: kubectl logs job/train --previous
    kubectl get job train -o jsonpath='{.spec.template.spec.terminationGracePeriodSeconds}'

`train` logs "received SIGTERM" when the signal reaches it. Does it?
---
- The kubelet signals PID 1 of the container only. Which process is PID 1 when
  the command is `sh -c '...; train ...'`? (`kubectl exec job/train -- cat /proc/1/cmdline`)
- How long does the trainer need after the signal? A checkpoint takes 5 s here
  (`CKPT_WRITE_SECONDS`), plus the step in progress.
---
    args: ['echo "train starting on $(hostname)"; exec train --seed 1 --log-every 25']
    terminationGracePeriodSeconds: 30

Delete and re-create the Job; once it is past step 100, run `kdrill verify`.
