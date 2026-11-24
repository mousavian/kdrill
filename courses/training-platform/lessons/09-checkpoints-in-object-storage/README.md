# Checkpoints in object storage (MinIO)

## Concept

On real clusters, checkpoints and datasets usually live in **object
storage**: Amazon S3, Google Cloud Storage, Azure Blob, or an S3-compatible
store such as MinIO or Ceph RGW. Unlike a `ReadWriteOnce` volume, a bucket is
reachable from every node and every cluster, holds any amount of data, and is
cheap. The price: it is not a filesystem. You `PUT` and `GET` whole objects
over HTTP (no appends, no renames, no locks), so programs write a checkpoint
as a new object and read the newest one back.

Clients find the store and authenticate through a few standard variables,
understood by boto3, the AWS CLI and most SDKs: `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, and `AWS_ENDPOINT_URL` for anything that is not
Amazon S3 itself. Credentials belong in a **Secret**, loaded with
`env[].valueFrom.secretKeyRef` or `envFrom[].secretRef`, never in the Job
spec: anyone who can read Jobs can read their environment, and specs end up in
Git.

The course's `train` treats a `CKPT_DIR` of the form `s3://BUCKET/PREFIX`
like a directory: checkpoints, `latest` and `metrics.json` become objects
under the prefix, and `RESUME=auto` looks for the newest checkpoint there.

## The situation

MinIO runs in the namespace (Service `minio`, S3 API on port 9000; one pod,
data in an emptyDir). The bucket `checkpoints` holds a previous run's
checkpoint at `shakespeare/ckpt-000300.pt`. Secret `s3-credentials` has the
keys `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. Job `train` should
continue that run to step 600, but it has no endpoint and some keys copied
from a wiki.

## Your task

Job `train`, with `CKPT_DIR=s3://checkpoints/shakespeare`, `STEPS=600` and no
PersistentVolumeClaim:

- `AWS_ENDPOINT_URL` points at the MinIO Service (`http://minio:9000`);
- `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` come from the Secret
  `s3-credentials`, with no literal values in the Job;
- it resumes from step 300 and completes: the bucket then holds
  `metrics.json` with status `done` at step 600 and a step-600 checkpoint.

## Useful commands

    kubectl logs job/train
    kubectl get secret s3-credentials -o jsonpath='{.data}'
    kubectl run s3 --rm -it --restart=Never --image=kdrill.local/ml-tiny:0.1.0 \
      --env=AWS_ENDPOINT_URL=http://minio:9000 \
      --overrides='{"spec":{"containers":[{"name":"s3","image":"kdrill.local/ml-tiny:0.1.0","stdin":true,"tty":true,"envFrom":[{"secretRef":{"name":"s3-credentials"}}],"env":[{"name":"AWS_ENDPOINT_URL","value":"http://minio:9000"}],"command":["mlt","ls","s3://checkpoints/shakespeare"]}]}}'

Setup takes about a minute (MinIO plus the previous run); the fixed Job about
20 seconds.

## On a real cluster

Pods get cloud credentials without static keys: IRSA or EKS Pod Identity on
AWS, Workload Identity on GKE and Azure, so there is no Secret to leak.
Checkpoints of large models are sharded (one object per rank) and written in
parallel; libraries such as PyTorch Distributed Checkpoint or the S3
connectors stream them. A single MinIO pod with an emptyDir, as here, loses
everything when the pod goes; real MinIO runs distributed with erasure coding
on persistent disks.

## Read more

- https://kubernetes.io/docs/concepts/configuration/secret/
- https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/#define-container-environment-variables-using-secret-data
- https://docs.aws.amazon.com/sdkref/latest/guide/feature-ss-endpoints.html
- https://github.com/minio/minio
