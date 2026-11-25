# 10 - Which layers to adapt

## Concept

LoRA does not say *where* to put the adapters. The original paper adapted only the attention projections; later work
(the QLoRA paper among others) found that adapting **all** linear layers, including the feed-forward ones, matters more than
turning the rank up. The reason is where a transformer keeps what it knows:

- **Attention** layers decide *where to look*: how information moves between positions. They are good at routing and pattern
  (copy this, attend to that), and adapting them is often enough to change style or format.
- **MLP (feed-forward) layers** act like a key-value memory per position and hold much of the model's *facts*. If the new
  behaviour is "know these things", the adapters have to reach them.

This task has both parts. The format (`A:` then one word then stop) is a pattern and attention alone learns it. The answers
are 160 facts the model has never seen, so they have to be stored somewhere. The experiment of this lesson is an
**ablation**: change one thing (the placement), keep everything else the same (data, rank, steps, seed), measure the effect.

Placement also decides cost. The number of trainable parameters is a formula you can compute from the layer shapes **before**
building anything: `sum(r * (in + out))` over the wrapped layers. An engineer sizing a run (memory, adapter file size) wants that
number without allocating the model. The per-head `query`, `key` and `value` of this GPT are thin (96 to 24), the MLP layers are
wide (96 to 384 and back), so one MLP layer costs roughly as much as several heads at the same rank.

Read the results as a trade: parameters bought, accuracy gained. "Attention+MLP" is more than twice as expensive as "qv" and
may well be worth it; "MLP only" shows that the MLP alone is not enough here either, because it cannot learn to route.

## The situation

`targets.py` has a table of named groups, and imports `add_lora` (08), `train_sft` (06) and `evaluate_qa` (01) from your
earlier files. `run_targets.py` compares four placements on the question-answer task.

## Your task

Implement `select_targets`, `predict_trainable` and `compare_targets`. Verify checks the group table, that the prediction
equals the true trainable count after `add_lora` for every group and several ranks (and that predicting changes nothing), the
structure of the comparison (and that the base stays untouched), and an outcome run of 250 steps on the question-answer
task: attention+MLP adapters must reach at least 0.08 more exact match than attention only, with both answering in the
format. Then:

    make py F=run_targets.py     # about 35 s

Reference numbers (rank 8, 250 steps, one seed): qv about 0.2, attention only about 0.25 to 0.4, MLP only about 0.15,
attention+MLP about 0.5 to 0.6; all near 100 percent format. Seeds move these numbers by 10 points or more (lesson 16), the
ordering attention+MLP above the rest is the stable part.

## Useful commands

- `make py F=run_targets.py`; `cat results/targets.json`
- `kdrill hint`, `kdrill reset`

## On a real project

`peft` takes `target_modules=["q_proj", "v_proj"]` or `"all-linear"`. Practitioners often start with all linear layers at a
low rank and shrink only if size matters. The finding to remember is that where you adapt and how much data you have usually
beat fine rank tuning.

## Read more

- QLoRA: Efficient Finetuning of Quantized LLMs (all-layer adapters, section 5): https://arxiv.org/abs/2305.14314
- Transformer Feed-Forward Layers Are Key-Value Memories: https://arxiv.org/abs/2012.14913
- Locating and Editing Factual Associations in GPT: https://arxiv.org/abs/2202.05262
