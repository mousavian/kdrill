# Hyperparameters in a ConfigMap, reproducible with a seed

## Concept

An experiment is defined by its **hyperparameters** (learning rate, batch
size, number of steps, model size) and its **random seed**. Buried in a
command line, they are easy to get subtly different between two Jobs, and hard
to see. Kubernetes has a place for configuration that is not code: a
**ConfigMap**. If the training program reads its settings from environment
variables, `envFrom: [{configMapRef: {name: hparams}}]` turns every key of the
ConfigMap into a variable, and one small object describes the run. Keep in
mind that pods read a ConfigMap only when they start: editing it changes the
next run, not a running one.

The seed matters more than it looks. Initial weights, the order of training
batches and dropout all come from a pseudo-random generator; without a fixed
seed every run is a different sample, and the loss of two "identical" runs
differs by more than many of the changes you might want to measure. With a
fixed seed, CPU training is **bit-for-bit reproducible** as long as the
software and the number of threads stay the same (parallel reductions add
numbers in a different order with a different thread count). On GPUs, some
kernels are non-deterministic unless you ask for deterministic algorithms.

The course's `train` reads every option from a flag or an environment
variable of the same meaning (`train --help`), and a flag wins over the
variable. It logs the seed it used, with `(random)` when none was given.

## The situation

Jobs `run-a` and `run-b` are the same experiment (300 steps, learning rate
0.003, batch 32), with the hyperparameters written as arguments in each Job.
They finish with different losses.

## Your task

- ConfigMap `hparams` with the keys `STEPS` (at least 300), `LR`,
  `BATCH_SIZE` and `SEED` (a number).
- Jobs `run-a` and `run-b` load it with `envFrom`, and set none of those four
  hyperparameters themselves (no `--steps/--lr/--batch-size/--seed` arguments,
  no literal `STEPS/LR/BATCH_SIZE/SEED` env entries).
- Both complete with a loss below 2.9, both log the seed from `hparams`, and
  their final losses are identical.

## Useful commands

    kubectl logs job/run-a | grep -E "seed=|final_loss"
    kubectl run help --rm -it --restart=Never --image=kdrill.local/ml-tiny:0.1.0 -- train --help
    kubectl create configmap --help
    kubectl delete job run-a run-b

Each run takes about 30 seconds.

## On a real cluster

Experiment configuration usually lives in versioned files (YAML/Hydra configs)
baked into the image or mounted from a ConfigMap as a file, and the tracker
records it with the run. Distributed GPU runs are reproducible only within
limits (non-deterministic kernels, different GPU counts); teams fix seeds
anyway, so that differences come from the change under test and not from luck.

## Read more

- https://kubernetes.io/docs/concepts/configuration/configmap/
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#configure-all-key-value-pairs-in-a-configmap-as-container-environment-variables
- https://docs.pytorch.org/docs/stable/notes/randomness.html
