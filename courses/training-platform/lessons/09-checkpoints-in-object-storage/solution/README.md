# Solution

From the lesson directory:

    kubectl delete job train
    kubectl apply -f solution/train.yaml
    kubectl logs -f job/train | head -n 3   # "resumed from ckpt-000300.pt at step 300"

- Without `AWS_ENDPOINT_URL` the S3 client talks to Amazon S3 itself; the
  standard variable (read by boto3, the AWS CLI and most SDKs) points it at
  MinIO's Service instead.
- The credentials come from the Secret with `secretKeyRef` (or, since the
  Secret's keys are already the variable names,
  `envFrom: [{secretRef: {name: s3-credentials}}]`). They are no longer in the
  Job spec, where anyone who can read Jobs sees them.
- The checkpoint location did not change, so the run found
  `shakespeare/ckpt-000300.pt` in the bucket and continued at step 300; every
  new checkpoint and `metrics.json` went to the bucket too. No volume is
  involved: any pod on any node could resume this run.
