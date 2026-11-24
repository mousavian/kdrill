    kubectl logs -l batch.kubernetes.io/job-name=sweep --prefix | grep "learning rate"
    kubectl get job sweep -o jsonpath='{.spec.completionMode}'

Every pod says "run 0". Where should the index come from?
---
`completionMode: Indexed` gives every pod its own index in the env var
`JOB_COMPLETION_INDEX` (0, 1, 2 for `completions: 3`). The Job's spec cannot
be edited: delete and re-create it. When it is done, the last log line of each
index has its `val_loss`:

    kubectl logs -l batch.kubernetes.io/job-completion-index=1 --tail=1
---
    kubectl delete job sweep
    kubectl apply -f solution/sweep.yaml
    kubectl wait job/sweep --for=condition=Complete --timeout=240s
    kubectl create configmap sweep-result --from-literal=best-lr=<lr with the lowest val_loss>
