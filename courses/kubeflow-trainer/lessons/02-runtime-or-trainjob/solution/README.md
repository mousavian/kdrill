# Solution

From the lesson directory:

    kubectl apply -f solution/team-runtime.yaml
    kubectl apply -f solution/trainjob.yaml
    kdrill verify            # about 20 s for the run

- `kind: TrainingRuntime` is the namespaced twin of `ClusterTrainingRuntime`: same spec, but it
  lives in one namespace and only TrainJobs of that namespace can reference it. The team owns it.
- `runtimeRef.kind` defaults to `ClusterTrainingRuntime`, so the original TrainJob looked for a
  cluster runtime called `team-tiny` and was refused: `runtime 'team-tiny' not found`. A
  namespaced runtime must be named with `kind: TrainingRuntime`.
- The TrainJob stays small: it sets only the team's own `RUN_TEAM` variable. The image, command,
  arguments (150 steps, seed 7), resources and policy come from the runtime.
- The platform's `tiny-gpt` was never touched.
