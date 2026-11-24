# Solution

From the lesson directory:

    kubectl delete job train
    kubectl apply -f solution/pvc.yaml -f solution/job.yaml
    kubectl logs job/train -c prepare
    kubectl logs job/train | head -n 3      # data=/data/input.txt chars=1115390 ... prepared=yes

- A ConfigMap is limited to 1 MiB (`kubectl create configmap ... --from-file`
  with the 1.1 MB corpus fails with "must have at most 1048576 bytes"), and it
  lives in etcd, the cluster's database, which is no place for datasets.
- The PVC `dataset` (local-path, ReadWriteOnce) is bound only when the first
  pod that uses it is scheduled (`WaitForFirstConsumer`), so it shows
  `Pending` until then.
- The init container `prepare` unpacks and cleans the archive into the volume
  and writes `meta.json`; `train` starts only after it exits 0, and reads the
  directory. Running the Job again finds the data already there (prepare is
  idempotent). A separate data-preparation Job writing the same PVC works too.
