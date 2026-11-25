# 02 - Full fine-tuning

## Concept

**Full fine-tuning** is pre-training with a smaller aim: start from the trained weights, keep the same loss (predict the
next token), feed it the new data, and update *every* parameter. Nothing new is added to the model. What changes are
the numbers in it, and how far they move depends on three knobs you control:

- **Learning rate.** Pre-training used 4e-3 here, with a large dataset. Fine-tuning a trained model on a small set needs a
  much smaller step: the weights are already in a good place, and a large step throws that away before the new data
  has taught anything. Typical fine-tuning rates are 10 to 100 times lower than pre-training rates.
- **Steps.** A few hundred steps over a few thousand tokens is many passes over the same text. Past the point where the
  held-out loss stops falling, extra steps only memorise the training text.
- **Schedule.** A short linear warm-up (the first Adam steps are noisy) and a cosine decay to a fraction of the rate help
  the run end in a calm place.

Always read the **held-out** loss, never only the training loss: the training loss of a fine-tuning run falls fast and
tells you little about whether the new voice has been learned or just the 8 chapters you trained on. The data here is
*Alice in Wonderland* chapters 1 to 8 (about 100 thousand characters, 40 thousand tokens); chapters 9 and 10 are the
validation set; chapters 11 and 12 stay untouched until the capstone.

`finetune` also leaves the door open for later lessons: it trains only the parameters with `requires_grad=True`, so
freezing (lesson 04) and LoRA (lesson 08) will reuse it unchanged.

## The situation

`finetune.py` has three functions with docstrings that fix every detail (so two people get the same numbers).
`run_full_ft.py` uses them at three learning rates and prints the style loss and the original loss for each.

## Your task

Implement `lr_at`, `get_batch` and `finetune`. Verify checks the schedule values, the batches, that every weight
moves, that the run is reproducible for a seed, that 150 steps lower the held-out style loss by a clear margin, and that
a learning rate twenty times higher ends worse than a small one. Then run the experiment:

    make py F=run_full_ft.py     # about 35 s

Read the table. With the reference base: base 3.46 style / 2.92 original; lr 3e-4 about 3.02 / 2.99; lr 1e-3 about
2.96 / 3.13; lr 3e-3 about 3.00 / 3.39. Style loss is best at 1e-3 and gets worse again at 3e-3 (a step that is too
large), while the damage to the original text grows with the rate. Note that **original loss went up in every row**;
lesson 03 is about that.

## Useful commands

- `make py F=run_full_ft.py`, `kdrill hint`, `kdrill reset`.
- `python3 -c` style experiments: `kdrill py` opens a shell where `from base import *` works.

## On a real project

Large runs use mixed precision (`bfloat16`), gradient accumulation, learning-rate warm-up of a few percent of the steps,
and often a different optimizer state sizing; the 10x to 100x lower learning rate rule is the same. Many teams never
do full fine-tuning of large models any more because of memory (the optimizer keeps two extra copies of every weight);
that is the motivation for lessons 08 to 13.

## Read more

- Universal Language Model Fine-tuning for Text Classification (discriminative rates, gradual unfreezing): https://arxiv.org/abs/1801.06146
- Decoupled Weight Decay Regularization (AdamW): https://arxiv.org/abs/1711.05101
- Revisiting Few-sample BERT Fine-tuning (warm-up and instability): https://arxiv.org/abs/2006.05987
