"""Lesson 18 - batches, evaluation and the training loop (PyTorch).

Convention for every model in the rest of the course:
    logits, loss = model(idx, targets=None)
idx is a (B, T) LongTensor of token ids, logits (B, T, V); loss is None without targets.
"""
import torch
import torch.nn as nn
import torch.nn.functional as F


class BigramLM(nn.Module):
    """(given) The neural bigram of lesson 13 as an nn.Module: a V x V table of logits."""

    def __init__(self, vocab_size):
        super().__init__()
        self.table = nn.Embedding(vocab_size, vocab_size)

    def forward(self, idx, targets=None):
        logits = self.table(idx)
        loss = None
        if targets is not None:
            loss = F.cross_entropy(logits.reshape(-1, logits.shape[-1]), targets.reshape(-1))
        return logits, loss


def get_batch(data, block_size, batch_size, generator=None):
    """Random training windows from a 1-D LongTensor of token ids.

    Draw `batch_size` start positions i with torch.randint(0, len(data) - block_size,
    (batch_size,), generator=generator). x[b] = data[i : i + block_size] and
    y[b] = data[i + 1 : i + block_size + 1]: the target of every position is the NEXT
    token. Both are (batch_size, block_size) LongTensors. A window never runs past the end
    of data. Raise ValueError if len(data) <= block_size."""
    # TODO
    raise NotImplementedError


@torch.no_grad()
def evaluate(model, data, block_size, batch_size, iters, generator=None):
    """Mean loss (a Python float) over `iters` random batches of `data`, without learning:
    no gradients are tracked (the decorator does that), the model is put in eval mode, and
    its previous mode (train or eval) is restored before returning."""
    # TODO
    raise NotImplementedError


def train(model, train_data, val_data, block_size, batch_size, steps, lr, eval_every=100,
          eval_iters=20, seed=0, weight_decay=0.0, log=print):
    """Train `model` with torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=weight_decay).

    - Training batches: get_batch(train_data, ...) with ONE generator
      g = torch.Generator().manual_seed(seed) used for nothing else, so a run is reproducible.
    - Each step: model.train(); forward with targets; optimizer.zero_grad(set_to_none=True);
      loss.backward(); optimizer.step().
    - Evaluate at the START of every step with step % eval_every == 0 (before that step's
      update; so step 0 is the untrained model) and once more after the final update,
      labelled step = steps: evaluate() on train_data
      and on val_data, each with a fresh torch.Generator().manual_seed(1234) (same eval batches
      every time, and the training generator is not touched). Append
      {"step": step, "train_loss": float, "val_loss": float} to the history and call
      log("step %d: train loss %.4f, val loss %.4f" % (...)).
    - val_data is only ever used inside evaluate(): never for a gradient.
    Return the history list."""
    # TODO
    raise NotImplementedError
