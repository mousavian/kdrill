"""Lesson 02 - reference solution."""
import math

import torch


def lr_at(step, steps, lr, warmup=0, min_ratio=0.1):
    if step < warmup:
        return lr * (step + 1) / warmup
    lr_min = lr * min_ratio
    if step >= steps:
        return lr_min
    progress = (step - warmup) / max(1, steps - warmup)
    return lr_min + 0.5 * (1 + math.cos(math.pi * progress)) * (lr - lr_min)


def get_batch(ids, block_size, batch_size, generator):
    if len(ids) <= block_size:
        raise ValueError("data is not longer than one block")
    ix = torch.randint(0, len(ids) - block_size, (batch_size,), generator=generator).tolist()
    x = torch.stack([ids[i:i + block_size] for i in ix])
    y = torch.stack([ids[i + 1:i + block_size + 1] for i in ix])
    return x, y


def finetune(model, ids, steps, lr, batch_size=16, block_size=None, seed=0, warmup=0, weight_decay=0.0):
    block_size = block_size or model.block_size
    g = torch.Generator().manual_seed(seed)
    params = [p for p in model.parameters() if p.requires_grad]
    opt = torch.optim.AdamW(params, lr=lr, betas=(0.9, 0.95), weight_decay=weight_decay)
    was = model.training
    model.train()
    losses = []
    for step in range(steps):
        for pg in opt.param_groups:
            pg["lr"] = lr_at(step, steps, lr, warmup)
        x, y = get_batch(ids, block_size, batch_size, g)
        _, loss = model(x, y)
        opt.zero_grad(set_to_none=True)
        loss.backward()
        opt.step()
        losses.append(float(loss.item()))
    model.train(was)
    return losses
