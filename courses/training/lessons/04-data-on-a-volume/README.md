# Data in: a prepared dataset on a volume

## Concept

Training data does not belong in the container image (it changes more often
than code, and it can be terabytes) and not in a **ConfigMap** either: a
ConfigMap is stored in etcd, the cluster's own database, and is capped at
**1 MiB**. The usual path is a volume, filled by a data-preparation step
before training starts.

A **PersistentVolumeClaim** (PVC) asks for storage from a StorageClass. k3s
ships `local-path`, which gives each claim a directory on the node's disk.
Its binding mode is `WaitForFirstConsumer`: the PVC stays `Pending` until a
pod that uses it is scheduled, so the volume is created on the node where
that pod runs. Its access mode is `ReadWriteOnce`: mountable read-write by
pods on **one node** at a time (several pods on the same node are fine).

The preparation step (download, unpack, clean, tokenise, shard) can be a
separate Job that writes the volume, or an **init container** in the training
pod: init containers run one after the other, each to completion, before the
main containers start; if one fails, the pod does not start training. Making
the step idempotent (skip when the data is already there) means retries and
reruns are cheap.

The course image ships the corpus as an archive,
`/opt/ml-tiny/datasets/tinyshakespeare.txt.gz`, standing in for a bucket or a
URL so nothing is downloaded during lessons. `prepare --src ARCHIVE --out DIR`
writes `DIR/input.txt` and `DIR/meta.json`; `train` accepts a file or such a
directory in `DATA`, and logs `chars=... prepared=yes|no`.

## The situation

Job `train` mounts the ConfigMap `corpus` at `/data`. Someone had to cut the
corpus to its first 200,000 characters to make it fit. The image's own
plain-text copy under `/opt/ml-tiny/data` is for quick experiments only.

## Your task

- A PVC `dataset` (storageClassName `local-path`).
- Job `train` prepares the full corpus onto it (init container or separate
  Job) and trains on that prepared data: 300 steps, final loss below 2.9, the
  log shows `chars=` over 1,000,000 and `prepared=yes`, and the data file is
  on the `dataset` volume. The ConfigMap `corpus` is no longer used.

## Useful commands

    kubectl logs job/train | head -n 3
    kubectl get pvc
    kubectl logs job/train -c <init-container-name>
    kubectl explain pod.spec.initContainers
    kubectl run help --rm -it --restart=Never --image=kdrill.local/ml-tiny:0.1.0 -- prepare --help

The fixed Job takes about 30 seconds.

## On a real cluster

`local-path` volumes live on one node: a pod scheduled on another node cannot
use them, and the data is lost with the node. Multi-node clusters use network
storage: a ReadWriteMany filesystem (NFS, CephFS, Amazon EFS, Filestore,
Lustre/FSx for big training sets) or, most often, object storage (S3, GCS)
read directly by the data loader, with a node-local cache. Large datasets are
prepared once by a pipeline and versioned, not by every training pod.

## Read more

- https://kubernetes.io/docs/concepts/configuration/configmap/
- https://kubernetes.io/docs/concepts/storage/persistent-volumes/
- https://kubernetes.io/docs/concepts/workloads/pods/init-containers/
- https://github.com/rancher/local-path-provisioner
