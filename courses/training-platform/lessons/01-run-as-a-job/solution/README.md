# Solution

From the lesson directory:

    kubectl delete deployment train
    kubectl apply -f solution/job.yaml
    kubectl wait job/train --for=condition=Complete --timeout=180s
    kubectl logs job/train | tail -n 1
    # done: step 400 final_loss=2.4xxx val_loss=... (your number)
    kubectl create configmap result --from-literal=final_loss=<the number after final_loss=>

Or in one go, once the Job is complete:

    kubectl create configmap result \
      --from-literal=final_loss="$(kubectl logs job/train | sed -n 's/.*final_loss=\([0-9.]*\).*/\1/p')"

Why: a Deployment's pods always have `restartPolicy: Always`, so a process
that exits 0 is started again (the pod goes Completed -> CrashLoopBackOff and
burns CPU retraining the same model). A Job runs its pod until it **succeeds**
`completions` times and then stops; `restartPolicy` must be `Never` or
`OnFailure`. The pod stays (Completed) so its logs can still be read.
