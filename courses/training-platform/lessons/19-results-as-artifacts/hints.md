    kubectl logs job/shakespeare-v2 | head -n 4
    kubectl run ls --rm -it --restart=Never --image=kdrill.local/ml-tiny:0.1.0 \
      --overrides='{"spec":{"containers":[{"name":"ls","image":"kdrill.local/ml-tiny:0.1.0","command":["ls","-R","/ckpt"],"volumeMounts":[{"name":"c","mountPath":"/ckpt"}]}],"volumes":[{"name":"c","persistentVolumeClaim":{"claimName":"checkpoints"}}]}}'

"resumed from ckpt-000600.pt": whose checkpoint is that?
---
- The run name: an env var `RUN_NAME` from `fieldRef` `metadata.labels['batch.kubernetes.io/job-name']`.
- Then `CKPT_DIR=/ckpt/$(RUN_NAME)` and `MODEL_OUT=/models/$(RUN_NAME)`
  ($(VAR) works for variables defined earlier in the same list).
- `CKPT_KEEP=2`, and `ttlSecondsAfterFinished` on the Job.
- Run `sample` after the training Job is complete.
---
    kubectl delete job shakespeare-v2
    kubectl apply -f solution/train-v2.yaml
    kubectl wait job/shakespeare-v2 --for=condition=Complete --timeout=180s
    kubectl apply -f solution/sample.yaml
