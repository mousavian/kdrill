# 04 - Freezing: train only part of the model

## Concept

Full fine-tuning updates every parameter, so the optimizer keeps extra state for every parameter (AdamW stores two
more numbers per weight) and every weight can drift away from what the model knew. **Freezing** trains only a chosen
subset: set `requires_grad = False` on the rest. A frozen parameter gets no gradient, is skipped by the optimizer, and
never changes.

Which subset? The usual intuition: lower layers hold general features (spelling, local syntax), upper layers hold more
task-specific behaviour, so adapting the **top** is cheap and often enough. The final LayerNorm is a tiny set of scale and
shift numbers; training only it is the cheapest possible change. The experiment of this lesson puts numbers on the
intuition for your model.

Practical details that bite:

- **Parameters are addressed by name.** `model.named_parameters()` gives names like `blocks.2.ffn.fc1.weight`. A prefix
  selects a whole block (`"blocks.2."`, with the dot, or `"blocks.1"` would also match `"blocks.10"`).
- **Tied weights.** The output layer shares its matrix with the token embedding (lesson 21 of `llm-from-zero`). It is one
  parameter, listed once under `tok_emb.weight`. "Train the output layer" and "train the embeddings" are the same
  switch here, and the count must not double it.
- **A typo freezes everything silently** if the prefix matches nothing, and training "succeeds" with a loss that never moves.
  Fail loudly instead.
- **Count what is trainable** and report it next to every result: "78 percent of the gain with 29 percent of the
  parameters" is the sentence you want.

Freezing also limits forgetting: weights that cannot move cannot be overwritten. It does not remove it (the trained part
still changes the function of the whole), but it shrinks it.

## The situation

`freeze.py` has five functions; `train_subset` ties them to the `finetune()` you wrote in lesson 02 (which only
optimises parameters that require gradients). `run_freeze.py` compares four choices with one budget.

## Your task

Implement `freeze_except`, `unfreeze_all`, `param_report`, `last_block_prefixes` and `train_subset`. Verify checks
flags and names, that a bad prefix raises and changes nothing, exact counts (a block has `12*C^2 + 10*C` parameters, the
final norm `2*C`, the tied matrix once), that after a run every frozen tensor is bit-identical (even with weight decay)
and the trained ones moved, and an outcome run: last block plus final norm gains at least 0.25 nats on held-out style
and ends clearly less damaged on the original text than full fine-tuning. Then:

    make py F=run_freeze.py     # about 30 s

With the reference base (150 steps, lr 1e-3): full 2.96 style / 3.13 original; last two blocks 3.03 / 3.01; last block
3.10 / 2.99; final norm only 3.41 / 2.90. What is the cheapest choice that still gets most of the style gain?

## Useful commands

- `kdrill py`, then `[n for n, p in model.named_parameters()]` to see the names.
- `kdrill hint`, `kdrill reset`

## On a real project

Freezing is the oldest parameter-efficient method and still common for classification heads on top of a frozen encoder.
For language models it has been largely replaced by adapters (LoRA, lessons 08 to 12), which keep the original weights
intact *and* let every layer change a little. Freezing the embeddings while training the rest is also common when the
vocabulary is shared across many models.

## Read more

- How transferable are features in deep neural networks?: https://arxiv.org/abs/1411.1792
- Universal Language Model Fine-tuning (gradual unfreezing): https://arxiv.org/abs/1801.06146
- PyTorch: autograd mechanics, excluding subgraphs from the backward pass: https://pytorch.org/docs/stable/notes/autograd.html#locally-disabling-gradient-computation
