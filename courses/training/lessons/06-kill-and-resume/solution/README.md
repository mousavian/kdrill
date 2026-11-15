# Solution

From the lesson directory:

    kubectl delete job train
    kubectl apply -f solution/train.yaml
    # wait until the log shows step 200 or later:
    kubectl logs -f job/train | grep -m1 "step 2[0-9]0/"
    kubectl delete pod -l batch.kubernetes.io/job-name=train
    kubectl logs -f job/train | grep -m1 resumed     # "resumed from ckpt-000NNN.pt at step NNN"
    kubectl wait job/train --for=condition=Complete --timeout=300s

Two things stopped the run from resuming:

- `RESUME=never` made every attempt start from step 0 even when checkpoints
  existed (`auto` loads the newest one).
- The checkpoints were in an emptyDir, which is deleted with the pod. A
  deleted pod is replaced by a **new** pod with a new, empty emptyDir. (With
  `restartPolicy: OnFailure`, a crashed *container* restarts in the same pod
  and would find its emptyDir, but a deleted, evicted or OOM-killed-and-replaced
  pod would not.)

`metrics.json` on the volume lists every attempt under `runs`: the second one
has `start_step` equal to the step the first one stopped at. `kubectl delete pod`
sends SIGTERM first, and this training script writes a checkpoint when it gets
SIGTERM, so nothing was lost; lesson 08 is about making that work.
