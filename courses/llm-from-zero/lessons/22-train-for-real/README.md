# 22 - Train it for real

## Concept

`train()` from lesson 18 is enough for a toy. A run that takes hours, on shared machines that get
preempted, needs four more things, and all four are small.

**A learning-rate schedule.** A constant rate is rarely best. Early on, the Adam statistics are
still noisy and the weights random, so a large rate can blow the run up: **warm up** linearly for
the first few percent of steps. Late in training you want small, careful steps to settle into a
minimum: **decay**, usually with a cosine shape, down to about a tenth of the peak. Warm-up plus
cosine decay is the default recipe of GPT-style training.

**Gradient clipping.** Occasionally a batch produces a huge gradient (a rare token, an unlucky
sequence) and one step throws the weights somewhere bad. Clipping rescales the whole gradient
vector so its **global L2 norm** is at most a threshold (1.0 is typical). It is one scale factor for
all parameters, so the *direction* of the update is kept. Log the pre-clip norm: a sudden rise is an
early warning of instability.

**Checkpoints.** Save everything needed to continue: the model, the **optimizer state** (Adam's
running averages are part of the model's training state; resuming without them silently changes the
run), the step, the config, and the **random-number states** (global torch RNG for dropout, the data
generator for batch order). Write to a temporary name and rename if a crash mid-write would hurt.

**Resume must be exact.** The real test of a checkpoint is that "run 10 steps, stop, start a new
process, run 10 more" gives *bit-for-bit* the same weights as 20 uninterrupted steps. It is the
easiest way to find the state you forgot to save, and it is what makes long runs on spot instances
and Kubernetes Jobs possible (the `training-platform` course builds on that).

## The situation

`train_gpt.py` has the schedule, the clipping, the checkpoint pair and `train_run`, which strings
them together using your `get_batch`/`evaluate` and GPT. `run_train.py` trains a small GPT on your real
data for a few minutes and resumes if you run it again.

## Your task

Implement `get_lr`, `clip_grad_norm` (by hand), `save_checkpoint`, `load_checkpoint` and `train_run`.
Verify checks the schedule values, the clipping against a reference (and that you did not call torch's
helper), the checkpoint round trip (including RNG states), **bit-for-bit resume with dropout in a fresh
model**, that clipping really happens before the optimizer step, the bookkeeping (lrs, norms, evaluation
steps, final checkpoint), that validation tokens never reach training, and that a tiny GPT learns text.

For the long run: `make py F=run_train.py` (about 2 minutes on 2 CPUs; run it again to watch it resume).

## Useful commands

- `kdrill py`; `kdrill hint`; `kdrill solution`.
- Stop `run_train.py` with Ctrl-C after a checkpoint appears, run it again, and compare the steps.

## On a real project

Add mixed precision, gradient accumulation, distributed data parallel, async checkpoint upload and a
metrics logger. Checkpoint format and resume logic stay the same.

## Read more

- SGDR: Stochastic Gradient Descent with Warm Restarts (cosine schedule): https://arxiv.org/abs/1608.03983
- On the difficulty of training recurrent neural networks (gradient clipping): https://arxiv.org/abs/1211.5063
- PyTorch, saving and loading a general checkpoint: https://pytorch.org/tutorials/recipes/recipes/saving_and_loading_a_general_checkpoint.html
