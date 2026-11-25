"""Lesson 06 - supervised fine-tuning with the loss on the answer tokens only.

An item is (ids, prompt_len): the token ids of prompt + completion (as made by sft_data.encode_example) and the
number of prompt tokens. Plain PyTorch only; not allowed: peft, trl, transformers.
"""
import torch
import torch.nn.functional as F


def make_batch(items, pad_id=0):
    """Turn a list of (ids, prompt_len) into three tensors of shape (B, L), L = longest len(ids) - 1:
      x     the inputs  ids[:-1], padded on the right with pad_id (LongTensor);
      y     the targets ids[1:],  padded on the right with pad_id (LongTensor);
      mask  float tensor, 1.0 where the TARGET y[b, t] = ids[t + 1] is a completion token, i.e. t + 1 >= prompt_len
            and the position is not padding; 0.0 for prompt targets and for padding."""
    # TODO
    raise NotImplementedError


def masked_loss(logits, targets, mask):
    """Mean cross-entropy over the positions where mask == 1: sum(nll * mask) / mask.sum(), with nll the per-position
    negative log-likelihood of `targets` under `logits` (B, L, V). Raise ValueError when the mask selects nothing."""
    # TODO
    raise NotImplementedError


def train_sft(model, items, steps, lr, batch_size=16, seed=0, pad_id=0, weight_decay=0.0):
    """Fine-tune `model` in place for `steps` AdamW steps (betas (0.9, 0.95), constant lr) on random batches:
    every step draws batch_size item indices with torch.randint(0, len(items), (batch_size,), generator=g) from
    g = torch.Generator().manual_seed(seed), builds the batch with make_batch, computes masked_loss on
    model(x)[0], clears gradients, backward, step. Only parameters that require gradients are optimised. Return
    the list of the losses; train mode during the run, previous mode restored."""
    # TODO
    raise NotImplementedError
