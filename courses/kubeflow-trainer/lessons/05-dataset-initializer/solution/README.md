# Solution

From the lesson directory:

    kubectl apply -f solution/runtime.yaml
    kubectl apply -f manifests/trainjob.yaml
    kdrill verify            # about 40 s: initializer, then the run

- A TrainJob with `spec.initializer.dataset` needs a runtime with a replicated job labelled
  `trainer.kubeflow.org/trainjob-ancestor-step: dataset-initializer`, a container called
  `dataset-initializer` and a volume mount named `initializer`; the webhook checks that and said
  `must have volumeMount with name - initializer in container dataset-initializer ...`.
- The volume itself comes from `volumeClaimPolicies` in the JobSet spec of the runtime: one PVC
  per TrainJob (`initializer-withdata`), mounted by both steps at `/workspace`. The trainer
  container needs the mount too, or `/workspace/dataset` would be empty for it.
- The controller turns `spec.initializer.dataset.storageUri` into the environment variable
  `STORAGE_URI` of the initializer container (and `secretRef` into credentials). What the initializer
  does with it is the initializer image's business: the real ones understand `hf://` and `s3://`;
  the lab's runs `prepare` on the file.
- `dependsOn: {name: dataset-initializer, status: Complete}` on the `node` job keeps the trainer
  waiting until the initializer's Job is complete; JobSet does not create the trainer's Job before
  that, so there are no pods for it.
