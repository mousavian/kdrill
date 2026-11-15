Look at what the run trained on:

    kubectl logs job/train | head -n 3        # chars=200000
    kubectl create configmap full --from-file=input.txt=<a 1.1 MB file> --dry-run=server

ConfigMaps (and Secrets) are capped at 1 MiB. The data has to come from a volume.
---
1. A PersistentVolumeClaim `dataset` (storageClassName `local-path`,
   ReadWriteOnce, 50Mi is plenty).
2. In the Job's pod: an `initContainers` entry running
   `prepare --src /opt/ml-tiny/datasets/tinyshakespeare.txt.gz --out /data`
   with the PVC mounted at /data.
3. The `train` container mounts the same PVC and gets `DATA=/data` (the
   directory, so it also finds `meta.json`).
---
See solution/pvc.yaml and solution/job.yaml:

    kubectl delete job train
    kubectl apply -f solution/pvc.yaml -f solution/job.yaml
