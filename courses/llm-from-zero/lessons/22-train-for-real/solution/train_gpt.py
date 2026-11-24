"""Lesson 22 - reference solution."""
import math
import os

import torch

from loop import evaluate, get_batch


def get_lr(step, warmup_steps, max_steps, max_lr, min_lr):
    if step < warmup_steps:
        return max_lr * (step + 1) / warmup_steps
    if step >= max_steps:
        return min_lr
    ratio = (step - warmup_steps) / (max_steps - warmup_steps)
    return min_lr + 0.5 * (1.0 + math.cos(math.pi * ratio)) * (max_lr - min_lr)


def clip_grad_norm(parameters, max_norm):
    grads = [p.grad for p in parameters if p.grad is not None]
    total = math.sqrt(sum(float((g.detach() ** 2).sum()) for g in grads))
    if total > max_norm:
        scale = max_norm / (total + 1e-6)
        for g in grads:
            g.mul_(scale)
    return total


def save_checkpoint(path, model, optimizer, step, config, data_generator):
    torch.save({"model": model.state_dict(), "optimizer": optimizer.state_dict(), "step": step, "config": config,
                "torch_rng": torch.get_rng_state(), "data_rng": data_generator.get_state()}, path)


def load_checkpoint(path, model, optimizer, data_generator):
    ck = torch.load(path, weights_only=False)
    model.load_state_dict(ck["model"])
    optimizer.load_state_dict(ck["optimizer"])
    torch.set_rng_state(ck["torch_rng"])
    data_generator.set_state(ck["data_rng"])
    return ck


def train_run(model, train_data, val_data, cfg, out_dir, resume=False, stop_after=None):
    opt = torch.optim.AdamW(model.parameters(), lr=cfg["max_lr"], betas=(0.9, 0.95), weight_decay=cfg["weight_decay"])
    g = torch.Generator().manual_seed(cfg["seed"])
    path = os.path.join(out_dir, "ckpt.pt")
    start = 0
    if resume:
        start = load_checkpoint(path, model, opt, g)["step"]
    end = cfg["max_steps"] if stop_after is None else min(stop_after, cfg["max_steps"])
    out = {"losses": [], "lrs": [], "grad_norms": [], "evals": []}
    os.makedirs(out_dir, exist_ok=True)
    for step in range(start, end):
        lr = get_lr(step, cfg["warmup_steps"], cfg["max_steps"], cfg["max_lr"], cfg["min_lr"])
        for pg in opt.param_groups:
            pg["lr"] = lr
        if step % cfg["eval_every"] == 0:
            v = evaluate(model, val_data, cfg["block_size"], cfg["batch_size"], cfg["eval_iters"], torch.Generator().manual_seed(1234))
            out["evals"].append({"step": step, "val_loss": v})
        x, y = get_batch(train_data, cfg["block_size"], cfg["batch_size"], g)
        model.train()
        _, loss = model(x, y)
        opt.zero_grad(set_to_none=True)
        loss.backward()
        out["grad_norms"].append(clip_grad_norm(model.parameters(), cfg["grad_clip"]))
        opt.step()
        out["losses"].append(float(loss.item()))
        out["lrs"].append(lr)
        if (step + 1) % cfg["save_every"] == 0 or step + 1 == end:
            save_checkpoint(path, model, opt, step + 1, cfg, g)
    return out
