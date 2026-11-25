"""Lesson 03 - forgetting, measured, and replay as a mitigation. Builds on lr_at and get_batch from your finetune.py."""
import torch

from finetune import get_batch, lr_at


def forgetting(before, after):
    """Relative damage: (after - before) / before, where before and after are the original-text loss of the
    model before and after fine-tuning. 0.10 means the loss on the old text got 10 percent worse."""
    # TODO
    raise NotImplementedError


def mixed_batch(new_ids, old_ids, batch_size, block_size, replay, generator):
    """One batch with a share `replay` (0 <= replay <= 1) of windows from the old text.

    n_old = round(replay * batch_size) windows come from old_ids and n_new = batch_size - n_old from new_ids,
    both through get_batch with the same generator, the new ones drawn FIRST. Return (x, y) with the new
    rows first and the old rows after them; with replay=0 the call must consume the generator exactly like
    get_batch(new_ids, block_size, batch_size, generator). Raise ValueError when replay is outside [0, 1]."""
    # TODO
    raise NotImplementedError


def finetune_mixed(model, new_ids, old_ids, steps, lr, replay=0.0, batch_size=16, block_size=None, seed=0, warmup=0):
    """finetune() of lesson 02 with batches from mixed_batch: AdamW(betas=(0.9, 0.95), weight_decay=0) over
    the parameters that require gradients, lr_at(step, steps, lr, warmup) before every step, generator
    torch.Generator().manual_seed(seed), train mode during the run (previous mode restored afterwards).
    Return the list of training losses. With replay=0 it must give exactly the weights finetune() gives."""
    # TODO
    raise NotImplementedError
