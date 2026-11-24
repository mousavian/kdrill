# 18 - Batches and the training loop, properly

## Concept

A language model is trained on an endless supply of tiny prediction problems cut from one long
sequence of token ids. The unit is the **batch**: pick `batch_size` random windows of
`block_size` tokens; the input `x` is the window and the target `y` is the same window shifted
by one, so at *every position* the label is the next token. One window of length 8 gives 8
training examples (predict token 2 from token 1, token 3 from tokens 1-2, and so on); a model
with attention (lesson 19) learns from all of them in a single pass.

The loop itself has a fixed rhythm you will see in every deep-learning codebase:

1. get a batch, 2. forward pass to a loss, 3. **`zero_grad`**, 4. **`loss.backward()`**,
5. **`optimizer.step()`**. Skipping step 3 makes gradients pile up across steps; the model still
runs and just trains badly.

Around it, three habits make the difference between a toy and a trustworthy run.

- **Evaluate periodically, on both splits, without learning.** `model.eval()` turns off
  training-only behaviour (dropout, later), `torch.no_grad()` stops graph building, and the
  previous mode is restored afterwards. Evaluating with the same batches each time makes
  consecutive numbers comparable instead of noisy.
- **Keep validation data away from gradients.** The only place `val_data` appears is the
  evaluation function. A test here feeds token ids that exist only in validation data and checks
  that the model never sees them in training mode.
- **Be reproducible.** One seeded generator for training batches, used for nothing else, means
  a run can be repeated or resumed (lesson 21).

**AdamW** is the optimiser nearly everyone uses: per-parameter adaptive step sizes plus
decoupled weight decay. It replaces the hand-written `p -= lr * grad` of the last lesson.

## The situation

`loop.py` gives you `BigramLM`, the neural bigram of lesson 13 as an `nn.Module`, and the
interface `logits, loss = model(idx, targets)` that every model in the course follows.

## Your task

Implement `get_batch`, `evaluate` and `train`. Verify checks batch shapes and the shift, that
windows never run past the data and that every valid start can occur, that evaluation is
read-only and restores the mode, the training loop against a reference loop (same final
parameters), the log and history format, that validation tokens never reach training, and a run
on real text.

`make py F=run_loop.py` trains the bigram on your real data.

## Useful commands

- `kdrill py`: `import torch; from loop import *`.
- `kdrill hint`; `kdrill solution`.

## On a real project

Add a `DataLoader` and several workers when data does not fit in memory, gradient accumulation
when a batch does not fit on the GPU, and a logger (TensorBoard, Weights & Biases). The skeleton
stays this one.

## Read more

- `torch.optim.AdamW`: https://pytorch.org/docs/stable/generated/torch.optim.AdamW.html
- Decoupled Weight Decay Regularization (AdamW): https://arxiv.org/abs/1711.05101
- PyTorch, what is `torch.nn` really? https://pytorch.org/tutorials/beginner/nn_tutorial.html
