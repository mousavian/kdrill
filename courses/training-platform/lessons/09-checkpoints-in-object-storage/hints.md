    kubectl logs job/train
    kubectl get secret s3-credentials -o jsonpath='{.data}'
    kubectl get svc minio

The client does not know about MinIO, and the keys in the Job are not the
ones in the Secret.
---
- `AWS_ENDPOINT_URL=http://minio:9000` sends S3 requests to MinIO.
- `env[].valueFrom.secretKeyRef` (or `envFrom.secretRef`) loads
  `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from the Secret; remove the
  literal values.
- Keep `CKPT_DIR=s3://checkpoints/shakespeare`: that is where the previous run's
  checkpoint is.
---
See solution/train.yaml:

    kubectl delete job train
    kubectl apply -f solution/train.yaml
