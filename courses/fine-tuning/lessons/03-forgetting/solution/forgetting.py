"""Lesson 03 - reference solution."""
import torch

from finetune import get_batch, lr_at


def forgetting(before, after):
    return (after - before) / before


def mixed_batch(new_ids, old_ids, batch_size, block_size, replay, generator):
    if not 0.0 <= replay <= 1.0:
        raise ValueError("replay must be between 0 and 1")
    n_old = int(round(replay * batch_size))
    n_new = batch_size - n_old
    parts = []
    if n_new:
        parts.append(get_batch(new_ids, block_size, n_new, generator))
    if n_old:
        parts.append(get_batch(old_ids, block_size, n_old, generator))
    return torch.cat([p[0] for p in parts]), torch.cat([p[1] for p in parts])


def finetune_mixed(model, new_ids, old_ids, steps, lr, replay=0.0, batch_size=16, block_size=None, seed=0, warmup=0):
    block_size = block_size or model.block_size
    g = torch.Generator().manual_seed(seed)
    opt = torch.optim.AdamW([p for p in model.parameters() if p.requires_grad], lr=lr, betas=(0.9, 0.95), weight_decay=0.0)
    was = model.training
    model.train()
    losses = []
    for step in range(steps):
        for pg in opt.param_groups:
            pg["lr"] = lr_at(step, steps, lr, warmup)
        x, y = mixed_batch(new_ids, old_ids, batch_size, block_size, replay, g)
        _, loss = model(x, y)
        opt.zero_grad(set_to_none=True)
        loss.backward()
        opt.step()
        losses.append(float(loss.item()))
    model.train(was)
    return losses
