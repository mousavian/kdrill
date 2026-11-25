"""Lesson 02 - full fine-tuning: continue training all the weights on new text.

Plain PyTorch. Not allowed: peft, trl, transformers, accelerate (and torch.nn.utils.clip_grad_norm_ is not needed).
"""
import math

import torch


def lr_at(step, steps, lr, warmup=0, min_ratio=0.1):
    """Learning rate of optimizer step `step` (0-based) in a run of `steps` steps.

    Linear warm-up: for step < warmup the rate is lr * (step + 1) / warmup.
    Then cosine decay from lr (at step == warmup) to lr * min_ratio (reached at step == steps):
        progress = (step - warmup) / max(1, steps - warmup)
        rate = lr_min + 0.5 * (1 + cos(pi * progress)) * (lr - lr_min),   lr_min = lr * min_ratio
    With warmup=0 the first step uses lr itself. Steps beyond `steps` stay at lr_min."""
    # TODO
    raise NotImplementedError


def get_batch(ids, block_size, batch_size, generator):
    """Random windows of a 1-D LongTensor: starts i = torch.randint(0, len(ids) - block_size, (batch_size,),
    generator=generator); x[b] = ids[i:i+block_size], y[b] = ids[i+1:i+block_size+1]. Return (x, y), each
    (batch_size, block_size). Raise ValueError when ids is not longer than block_size."""
    # TODO
    raise NotImplementedError


def finetune(model, ids, steps, lr, batch_size=16, block_size=None, seed=0, warmup=0, weight_decay=0.0):
    """Train `model` in place on the token ids `ids` for `steps` AdamW steps and return the list of the
    training losses (one float per step).

    - block_size defaults to model.block_size; the data generator is torch.Generator().manual_seed(seed),
      so two runs with the same seed see the same batches.
    - The optimizer is torch.optim.AdamW over the parameters that require gradients (all of them for now),
      betas (0.9, 0.95), weight decay `weight_decay`; before every step set every param group's lr to
      lr_at(step, steps, lr, warmup).
    - Loss: model(x, y) returns (logits, loss). Clear the gradients every step.
    - Put the model in train mode while training and restore the mode it had afterwards."""
    # TODO
    raise NotImplementedError
