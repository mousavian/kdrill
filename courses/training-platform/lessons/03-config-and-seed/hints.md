Compare the two runs:

    kubectl logs job/run-a | grep -E "seed=|final_loss"
    kubectl logs job/run-b | grep -E "seed=|final_loss"

Same arguments, different seeds. `kubectl run tmp --rm -it --image=kdrill.local/ml-tiny:0.1.0 --restart=Never -- train --help`
shows the environment variable that sets each option.
---
A ConfigMap whose keys are those variable names (STEPS, LR, BATCH_SIZE, SEED)
can be loaded into a container in one go with `envFrom: [{configMapRef: {name:
hparams}}]`. Remove the hyperparameter arguments from the Jobs (flags win over
environment variables). Keep OMP_NUM_THREADS the same in both.
---
    kubectl create configmap hparams --from-literal=STEPS=300 --from-literal=LR=0.003 \
      --from-literal=BATCH_SIZE=32 --from-literal=SEED=1234
    kubectl get job run-a -o yaml > jobs.yaml   # or start from manifests/jobs.yaml
    # args: [--log-every, "50"] and envFrom: [{configMapRef: {name: hparams}}] in both Jobs
    kubectl delete job run-a run-b; kubectl apply -f jobs.yaml
