"""Lesson 22 - a real training run (PyTorch). Uses get_batch/evaluate from your loop.py (lesson 18)
and the GPT from your gpt.py (lesson 21).

cfg is a dict with: block_size, batch_size, max_steps, warmup_steps, max_lr, min_lr,
weight_decay, grad_clip, eval_every, eval_iters, save_every, seed.
"""
import math
import os

import torch

from loop import evaluate, get_batch


def get_lr(step, warmup_steps, max_steps, max_lr, min_lr):
    """Learning rate at `step` (0-based):
    - step < warmup_steps: linear warm-up, max_lr * (step + 1) / warmup_steps
    - step >= max_steps: min_lr
    - otherwise cosine decay from max_lr down to min_lr:
        ratio = (step - warmup_steps) / (max_steps - warmup_steps)
        min_lr + 0.5 * (1 + cos(pi * ratio)) * (max_lr - min_lr)"""
    # TODO
    raise NotImplementedError


def clip_grad_norm(parameters, max_norm):
    """Clip the GLOBAL gradient norm, written by hand (not torch.nn.utils.clip_grad_norm_).
    total = sqrt(sum of squared entries of all .grad that are not None). If total > max_norm
    multiply every gradient by max_norm / (total + 1e-6). Return total (a float), measured
    BEFORE clipping."""
    # TODO
    raise NotImplementedError


def save_checkpoint(path, model, optimizer, step, config, data_generator):
    """torch.save a dict with the keys: "model" (state_dict), "optimizer" (state_dict), "step",
    "config", "torch_rng" (torch.get_rng_state()) and "data_rng" (data_generator.get_state())."""
    # TODO
    raise NotImplementedError


def load_checkpoint(path, model, optimizer, data_generator):
    """Load what save_checkpoint saved: restore the model and optimizer states, the global
    torch RNG state (torch.set_rng_state) and the data generator state. Return the whole
    checkpoint dict (so the caller can read "step" and "config")."""
    # TODO
    raise NotImplementedError


def train_run(model, train_data, val_data, cfg, out_dir, resume=False, stop_after=None):
    """Train `model` and return {"losses": [...], "lrs": [...], "grad_norms": [...], "evals": [...]}
    for the steps run in THIS call (losses, lrs and grad norms: one float per step; evals: a list of
    {"step": s, "val_loss": v}).

    - optimizer = torch.optim.AdamW(model.parameters(), lr=cfg["max_lr"], betas=(0.9, 0.95),
      weight_decay=cfg["weight_decay"]); data_generator = torch.Generator().manual_seed(cfg["seed"])
    - resume=True: load out_dir/ckpt.pt and continue from its "step"; otherwise start at step 0.
    - for step in range(start, cfg["max_steps"]) (stop early after the step with index
      stop_after - 1 when stop_after is given; the learning-rate schedule still uses max_steps):
        set every param group's lr to get_lr(step, ...); x, y = get_batch(train_data, block_size,
        batch_size, data_generator); model.train(); forward with targets; zero_grad; backward;
        grad norm = clip_grad_norm(model.parameters(), cfg["grad_clip"]); optimizer.step();
        record the loss, lr and grad norm.
      - before the update of every step with step % eval_every == 0: val loss =
        evaluate(model, val_data, block_size, batch_size, eval_iters,
        torch.Generator().manual_seed(1234)); record it in "evals".
      - after the update, if (step + 1) % save_every == 0, or the loop is about to end (last step
        run), save out_dir/ckpt.pt with step + 1 completed steps (create out_dir if needed).
    A run stopped and resumed must produce exactly the same parameters as an uninterrupted one,
    also with dropout (that is why the RNG states are in the checkpoint)."""
    # TODO
    raise NotImplementedError
