    kubectl logs job/train | grep checkpoint
    kubectl logs job/sample
    kubectl get job train -o jsonpath='{.spec.template.spec.volumes}'

The checkpoints were written, but where? What happens to an emptyDir when its
pod finishes? And when did `sample` run compared to `train`?
---
Mount the PVC `checkpoints` at /ckpt in the training pod instead of the
emptyDir (re-create the Job). Then create the sample Job only after the
training Job is Complete: `kubectl wait job/train --for=condition=Complete`.
---
    kubectl delete job train sample
    kubectl apply -f solution/train.yaml
    kubectl wait job/train --for=condition=Complete --timeout=180s
    kubectl apply -f solution/sample.yaml
