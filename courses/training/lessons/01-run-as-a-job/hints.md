Look at what the Deployment does after training finishes:

    kubectl get pods -w          # Completed -> CrashLoopBackOff -> Running ...
    kubectl logs deploy/train --previous | tail -n 3

The container is fine; the controller is the wrong one. Which workload kind
runs a pod until it succeeds and then stops?
---
A Job's pod template is the same as the Deployment's (the image, command,
args, env and resources can be copied), plus:

- `restartPolicy: Never` (or `OnFailure`); `Always` is not allowed in a Job
- no `replicas`/`selector`; optional `completions: 1`, `backoffLimit: 2`

Delete the Deployment first so the two do not compete for CPU.
---
    kubectl delete deployment train
    kubectl create job train --image=kdrill.local/ml-tiny:0.1.0 --dry-run=client -o yaml -- train --steps 400 --seed 1 > job.yaml
    # add env OMP_NUM_THREADS=1 and the resources, then: kubectl apply -f job.yaml
    kubectl wait job/train --for=condition=Complete --timeout=180s
    kubectl logs job/train | tail -n 1
    kubectl create configmap result --from-literal=final_loss=<value>
