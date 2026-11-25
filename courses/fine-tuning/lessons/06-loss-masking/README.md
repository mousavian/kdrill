# 06 - Loss masking: learn the answer, not the question

## Concept

In a training example like `Q: What colour is the lamp?\nA: grey<end>` every token is a prediction target, and the
ordinary next-token loss averages over all of them. But at test time the *question* is given; the model never has to
produce it. Only the answer tokens (and the stop token) are behaviour you want to teach. If you leave the prompt in the
loss, most of the gradient (four fifths here, you measured the `answer_share` in lesson 05) goes into modelling
the questions, which wastes capacity and can pull the model toward the wording of the prompts.

**Loss masking** fixes it: compute the per-token loss everywhere, multiply by a 0/1 mask that is 1 only on completion
targets, and divide by the number of selected tokens. The prompt still goes *through* the model (the answer depends on
it); it just does not contribute a loss, so its positions receive no gradient *at the output*.

Three details to get right:

- **Align the mask with the targets, not the inputs.** Position `t` of `x` predicts `ids[t + 1]`. The target at `t` is
  a completion token when `t + 1 >= prompt_len`. An off-by-one here trains on the last prompt token (`:`) or skips the
  first answer token, and the model quietly learns the wrong thing.
- **Padding.** Examples have different lengths; short ones are padded to a rectangle. Padding positions must have mask 0
  (and because attention is causal, padding on the *right* never influences earlier positions).
- **Divide by the number of selected tokens**, not by `B * L`, otherwise batches with long prompts get smaller gradients.

The best way to be sure a mask works is not to read the code but to **look at the gradient**: after `backward()`, the
gradient of the loss with respect to the logits must be exactly zero at every masked position. That is the check verify uses.

With the mask, `train_sft` takes the base model, which never stops and never answers, to a model that answers in the
format on every held-out prompt and gets most answers right; format is learned much faster than correctness.

## The situation

`masking.py` has `make_batch`, `masked_loss` and `train_sft`; the items come from your `sft_data.encode_all`.
`run_sft.py` trains twice with the same budget, with the answer-only mask and with a mask of ones, and evaluates both with
your lesson 01 harness.

## Your task

Implement the three functions. Verify checks the exact layout of a small batch, the loss on hand-made logits, the
**gradients at prompt and padding positions through the real model** (exactly zero) and at answer positions (non-zero), that
a padded batch gives the same loss as the examples one by one, reproducibility and frozen parameters, and an outcome run
(250 steps, lr 2e-3): at least 95 percent of held-out prompts answered in the format and at least 45 percent exactly right.
Then:

    make py F=run_sft.py      # about 25 s

Reference numbers: the base has format 0 and exact 0; after tuning, format 1.00 and exact roughly 0.6 to 0.8 with either loss.
On a task this small and a single seed, masking does **not** reliably win (one run gave 0.64 with the answer mask and 0.73 on all
tokens, another the opposite): the seed-to-seed spread is as large as the effect (lesson 16 gives you the tools to say so with
numbers). The argument for masking is the loss you optimise (only what the model must produce) and the way the benefit grows with
long prompts, not this table.

## Useful commands

- `make py F=run_sft.py`; `cat results/sft.json`
- `kdrill hint`, `kdrill reset`

## On a real project

Libraries call it "completion-only loss" or set the label of prompt tokens to `-100` (the `ignore_index` of cross-entropy).
Chat data masks the system and user turns and trains on the assistant turns only. Packing several short examples into one
sequence saves padding but needs a mask that also stops attention crossing example boundaries.

## Read more

- Instruction Tuning with Loss Over Instructions (does masking help?): https://arxiv.org/abs/2405.14394
- PyTorch `cross_entropy`, `ignore_index` and `reduction`: https://pytorch.org/docs/stable/generated/torch.nn.functional.cross_entropy.html
- Training language models to follow instructions with human feedback: https://arxiv.org/abs/2203.02155
