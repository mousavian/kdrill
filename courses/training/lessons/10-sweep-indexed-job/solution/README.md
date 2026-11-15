# Solution

From the lesson directory:

    kubectl delete job sweep
    kubectl apply -f solution/sweep.yaml
    kubectl wait job/sweep --for=condition=Complete --timeout=240s
    for i in 0 1 2; do
      kubectl logs -l batch.kubernetes.io/job-completion-index=$i --tail=1
    done
    kubectl create configmap sweep-result --from-literal=best-lr=<the lr with the lowest val_loss>

- A Job without `completionMode` is `NonIndexed`: its pods are
  interchangeable and get no index, so `JOB_COMPLETION_INDEX` was empty, every
  pod picked the first learning rate and wrote to `run-0`.
- With `completionMode: Indexed` the Job creates exactly one successful pod per
  index 0..completions-1; each pod has the index in the env var
  `JOB_COMPLETION_INDEX`, the annotation and label
  `batch.kubernetes.io/job-completion-index` and its hostname
  (`sweep-<index>`). A failed index is retried with the same index.
- `parallelism: 2` runs two at a time; the third starts when one finishes.

Read the winner from the logs: with seed 1 and 300 steps the largest rate
(0.03) does worst, and the order of the other two is not what everyone
guesses, which is the reason to sweep. Compare `val_loss` (held-out data), not
the training loss.
