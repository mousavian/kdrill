# 09 - Rank and alpha: a small sweep

## Concept

LoRA has two knobs you set before training: the **rank** `r` (how many directions the update may use) and **alpha** (how
loudly it speaks, since the update is multiplied by `alpha / r`). Both decide the number of trainable parameters and the
speed of learning, and neither has a right value in general. You find the values the same way for every
hyperparameter: **run controlled experiments and read a table**.

Three habits that make a sweep trustworthy:

- **An experiment is a function.** `lora_run(base, data, r, alpha, ...)` takes a base model and a setting and returns
  numbers, working on a *copy* so that run 5 does not start from run 4's leftovers. If results change when you reorder the
  runs, something leaks between them.
- **Same data, same seed, same budget** for every setting; vary one thing at a time. Part 1 here varies the rank with
  `alpha = 2r` (so the scale stays 2); part 2 varies alpha at a fixed rank.
- **A selection rule, written down.** "Looks good" is not a rule. `smallest_rank` says: the cheapest setting that reaches
  80 percent of the gain that full fine-tuning gets. Then someone else can rerun it and get the same answer.

What you should see: the loss falls with every doubling of the rank (about 0.04 nats per doubling here, 3.34 at r=1 to 3.18
at r=16 after 100 steps, with no flat part yet), and **alpha changes the learning speed**, not the capacity: with a small alpha
the update is damped (the scale `alpha / r` is `0.125` for `r=8, alpha=1`), so the same number of steps gets less done (3.34 at
alpha 1, 3.22 at 16, 3.18 at 64). A very large alpha eventually makes steps too big and noisy; this budget never reaches that
point, and the sweep says nothing beyond what it covers. Because Adam normalises step sizes, the interaction of alpha with the
learning rate is not simply multiplicative, which is why you test it.

One sweep on one seed is a hint, not a proof; lesson 16 puts error bars on such comparisons.

## The situation

`sweep.py` imports `add_lora` and `trainable_count` from your `lora.py`, `finetune` from lesson 02 and `text_loss` from
lesson 01. `run_sweep.py` runs the two sweeps and applies your selection rule.

## Your task

Implement `lora_run`, `run_sweep` and `smallest_rank`. Verify checks the selection rule on hand-made results (including
ties, order independence and `None`), that `lora_run` reports the right trainable count and leaves the base model untouched
(no adapters, no changed weight), reproducibility and independence of runs, and a short outcome run: rank 8 beats rank 1 by
at least 0.08 nats, and alpha 16 beats alpha 1 at the same rank. Then:

    make py F=run_sweep.py      # about 60 s

Read both tables and the two selection lines. With this budget (100 steps) no rank reaches 80 percent of the gain of full
fine-tuning (the script prints `none` for 80 percent and picks rank 8 for 50 percent): that is a finding, not a bug in your
function. What would you choose for a model you must ship, and why?

## Useful commands

- `make py F=run_sweep.py`; `cat results/sweep.json`
- `kdrill hint`, `kdrill reset`

## On a real project

Sweeps are run with a tracker (Weights & Biases, MLflow) and a search strategy (grid, random, Bayesian); budgets are set
so that the whole sweep fits the compute you have. Common defaults are `r` between 8 and 64 and `alpha` equal to `r` or
`2r`. The QLoRA authors found that the number of adapted layers mattered more than the rank, which is lesson 10's question.

## Read more

- LoRA: Low-Rank Adaptation of Large Language Models (section 7, which rank?): https://arxiv.org/abs/2106.09685
- A Rank Stabilization Scaling Factor for Fine-Tuning with LoRA: https://arxiv.org/abs/2312.03732
- LoRA Learns Less and Forgets Less: https://arxiv.org/abs/2405.09673
