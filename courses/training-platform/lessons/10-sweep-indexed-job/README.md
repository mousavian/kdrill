# A hyperparameter sweep as an Indexed Job

## Concept

Before a long training run, teams run many short ones: a **sweep** over
learning rate, batch size, warm-up and so on, then keep the best setting.
The runs are independent, so they map onto one Job with several
**completions**, `parallelism` of them at a time.

A plain Job's pods are interchangeable (`completionMode: NonIndexed`, the
default): the Job only counts successes. A sweep needs each pod to know
*which* run it is. With **`completionMode: Indexed`** the Job creates one
successful pod per index `0 .. completions-1` and hands each pod its index in
the environment variable `JOB_COMPLETION_INDEX`, the label and annotation
`batch.kubernetes.io/job-completion-index`, and the hostname `<job>-<index>`.
A failed pod is retried with the same index, and the Job is complete when
every index has succeeded. The same mechanism gives ranks to distributed
workers (next lesson) and shards to data-processing jobs.

`completions` and `parallelism` are independent: `completions: 3,
parallelism: 2` runs two, then the third, so a sweep larger than the cluster
still finishes. Compare runs on **validation loss** (data the model did not
train on), not training loss, and with the same seed and steps.

## The situation

PVC `results` exists. Job `sweep` (3 completions, 2 in parallel, 300 steps
each) maps the index to a learning rate (0.0003, 0.003, 0.03) and writes each
run's `metrics.json` to `/results/run-<index>`. All three runs say "run 0".

## Your task

- Job `sweep`: Indexed, still 3 completions, parallelism 1-3, the same three
  learning rates; it completes and each index trains its own learning rate
  (`results/run-0`, `run-1`, `run-2`, each `done` at step 300).
- ConfigMap `sweep-result` with key `best-lr`: the learning rate whose run
  had the lowest final `val_loss`.

## Useful commands

    kubectl get pods -L batch.kubernetes.io/job-completion-index
    kubectl logs -l batch.kubernetes.io/job-name=sweep --prefix | grep "learning rate"
    kubectl logs -l batch.kubernetes.io/job-completion-index=2 --tail=1
    kubectl create configmap sweep-result --from-literal=best-lr=...

The sweep takes about a minute.

## On a real cluster

Sweeps over hundreds of trials use a tuner that picks the next trial from the
results so far and stops bad ones early: Katib (Kubeflow), Ray Tune, Optuna.
They still create Jobs, or Ray tasks, per trial. Each trial gets GPUs, so
`parallelism` is set by the quota, and a queue (Part D) keeps a big sweep from
starving everyone else.

## Read more

- https://kubernetes.io/docs/concepts/workloads/controllers/job/#completion-mode
- https://kubernetes.io/docs/tasks/job/indexed-parallel-processing-static/
- https://kubernetes.io/docs/concepts/workloads/controllers/job/#controlling-parallelism
