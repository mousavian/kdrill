# Solution

From the lesson directory:

    kubectl delete job train sample
    kubectl apply -f solution/train.yaml
    kubectl wait job/train --for=condition=Complete --timeout=180s
    kubectl apply -f solution/sample.yaml
    kubectl wait job/sample --for=condition=Complete --timeout=60s
    kubectl logs job/sample

- An `emptyDir` lives and dies with its pod: the checkpoints were written, and
  deleted the moment the training pod finished. A PersistentVolumeClaim
  outlives every pod that mounts it, so the second Job can read what the first
  one wrote (`sample --model /ckpt` loads the newest `ckpt-*.pt`).
- Jobs have no ordering between them. `sample` started together with `train`,
  found an empty volume and failed; run it after `kubectl wait` reports the
  training Job Complete (pipelines tools such as Argo Workflows or Kubeflow
  Pipelines express that dependency for you).
- The training script keeps the newest 3 checkpoints (`CKPT_KEEP`), so the
  volume ends with ckpt-000400, -000500 and -000600, plus `latest` and
  `metrics.json`.
