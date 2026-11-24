# Solution

From the lesson directory:

    kubectl delete job shakespeare-v2 sample --ignore-not-found
    kubectl apply -f solution/train-v2.yaml
    kubectl wait job/shakespeare-v2 --for=condition=Complete --timeout=180s
    kubectl apply -f solution/sample.yaml
    kubectl logs -f job/sample

- Both runs used `CKPT_DIR=/ckpt`, so v2 found v1's step-600 checkpoint,
  "resumed" from it and was done at once: same model shape, same data, so
  nothing stopped it. Every run needs its own location. Deriving it from the
  Job's name (the label `batch.kubernetes.io/job-name` through the downward
  API, then `$(RUN_NAME)` in later variables) keeps the name and the path in
  step; a retry of the same Job still finds its own checkpoints.
- `CKPT_KEEP=2` deletes older checkpoints as new ones are written (`0` kept
  all twelve).
- `MODEL_OUT` writes `model.pt` (weights only, no optimizer state: smaller,
  what serving needs) and `model.json` (run name, steps, losses, data hash,
  seed, config) to `/models/shakespeare-v2/`: an artifact with its metadata.
- `ttlSecondsAfterFinished` removes the finished Job and its pods; the PVCs
  (and the artifacts on them) stay.
