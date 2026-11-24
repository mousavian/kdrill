# Solution

From the lesson directory:

    kubectl delete job ddp
    kubectl delete pvc checkpoints        # access modes cannot be changed in place
    kubectl apply -f solution/pvc.yaml -f solution/ddp.yaml
    kubectl logs -f -l batch.kubernetes.io/job-name=ddp --prefix

- `ReadWriteOncePod` lets exactly **one pod** mount the claim. Rank 0 got it;
  rank 1 stayed Pending ("PersistentVolumeClaim with ReadWriteOncePod access
  mode already in-use by another pod") and rank 0 waited for it at the
  rendezvous. A distributed job is all-or-nothing, so one Pending worker
  stops everything.
- `ReadWriteOnce` means one **node**: any number of pods on that node can
  mount it, which is enough here because the lab has a single node. On a
  multi-node cluster the workers land on different nodes, so the volume must
  be `ReadWriteMany` (a network filesystem) or the checkpoints go to object
  storage.
- The access mode of a PVC is immutable: delete the Job (its pods use the
  claim, and the claim is only deleted once no pod uses it), delete the PVC,
  create both again. The old checkpoints are gone with the old volume.
- Only rank 0 writes checkpoints (identical copies would race on the same
  files), but on resume **every** rank loads the checkpoint, which is why all
  workers mount the volume.
