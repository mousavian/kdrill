Delete the pod while it trains and watch the replacement's first lines:

    kubectl delete pod -l batch.kubernetes.io/job-name=train
    kubectl logs -f job/train | head -n 4

"starting at step 0": the new pod found no checkpoint, or did not look for one.
Look at the Job's env and volumes.
---
Two changes, then re-create the Job:

- `RESUME` must be `auto` (or removed: auto is the default);
- the checkpoint directory must be on the PVC `checkpoints`, not an emptyDir.

Then delete the running pod after the log shows step 200 or later (the run
needs to have written a checkpoint), and let the Job finish.
---
    kubectl delete job train
    kubectl apply -f solution/train.yaml
    kubectl logs -f job/train | grep -m1 "step 250/"
    kubectl delete pod -l batch.kubernetes.io/job-name=train
    kubectl wait job/train --for=condition=Complete --timeout=300s
