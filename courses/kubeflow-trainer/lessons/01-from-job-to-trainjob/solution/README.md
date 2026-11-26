# Solution

From the lesson directory:

    kubectl apply -f solution/runtime.yaml
    kubectl apply -f manifests/trainjob.yaml
    kdrill verify          # the run takes about 20 s

- The runtime is the Job's pod template, moved into
  `spec.template.spec.replicatedJobs[0]`. A ClusterTrainingRuntime is a template of a
  **JobSet**; the TrainJob is the request to run it.
- Applying the TrainJob before the runtime existed was refused at admission: webhooks look up
  the runtime named in `runtimeRef` (`runtime 'tiny-gpt' not found`), so a TrainJob never
  starts life pointing at nothing.
- The label `trainer.kubeflow.org/trainjob-ancestor-step: trainer` marks the replicated job
  that `spec.trainer` (image, command, args, env, numNodes, resources) of the TrainJob is
  applied to. The container must be named `node`.
- `mlPolicy.torch: {}` selects the PyTorch policy. With one node it only adds the `PET_*`
  environment variables (lesson 4 uses them); `numNodes: 1` is the default node count.
- The controller named the JobSet `tiny` after the TrainJob, the Job `tiny-node-0` after the
  replicated job, and set the TrainJob as the owner of the JobSet.
