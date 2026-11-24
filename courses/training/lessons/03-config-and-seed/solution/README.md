# Solution

From the lesson directory:

    kubectl delete job run-a run-b
    kubectl apply -f solution/hparams.yaml -f solution/jobs.yaml
    kubectl wait job/run-a job/run-b --for=condition=Complete --timeout=180s
    kubectl logs job/run-a | tail -n 1; kubectl logs job/run-b | tail -n 1

Both lines show the same `final_loss`.

- The script reads every hyperparameter from an environment variable as well as
  a flag (`train --help` lists them), so a ConfigMap with those keys and
  `envFrom` replaces the command-line arguments. One object now describes the
  experiment, and changing it (then re-creating the Jobs) changes both runs.
- Without a seed the script picks a random one (`seed=... (random)` in the log),
  so the initial weights and the batches differ between runs. A fixed `SEED`
  makes them identical; with the same thread count (`OMP_NUM_THREADS=1` here)
  CPU training is then bit-for-bit reproducible.
- Pods read ConfigMap values only when they start: editing `hparams` does not
  change a running Job, and a Job's template cannot be edited, so the Jobs are
  re-created.
