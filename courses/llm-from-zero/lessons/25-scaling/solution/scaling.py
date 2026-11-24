"""Lesson 25 - reference solution."""
import math
import os

import numpy as np
import torch

from gpt import GPT
from loop import evaluate, train


def train_flops(n_params, tokens):
    return 6.0 * n_params * tokens


def steps_for_budget(budget_flops, n_params, batch_size, block_size):
    return max(1, int(round(budget_flops / (6.0 * n_params * batch_size * block_size))))


def fit_power_law(xs, ys):
    xs, ys = np.asarray(xs, dtype=float), np.asarray(ys, dtype=float)
    if len(xs) < 2 or len(xs) != len(ys) or (xs <= 0).any() or (ys <= 0).any():
        raise ValueError("need at least two positive points")
    b, log_a = np.polyfit(np.log(xs), np.log(ys), 1)
    return float(np.exp(log_a)), float(b)


def predict_power_law(a, b, x):
    return a * x ** b


def plot_curves(curves, path, xlabel="compute (FLOPs)", ylabel="validation loss", title=""):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    fig, ax = plt.subplots(figsize=(6, 4))
    for label, pts in curves.items():
        xs, ys = zip(*pts)
        ax.plot(xs, ys, marker="o", label=label)
    ax.set_xscale("log")
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    ax.legend()
    fig.tight_layout()
    fig.savefig(path, dpi=100)
    plt.close(fig)
    return path


def run_one(config, budget_flops, train_ids, val_ids, vocab_size, block_size=32, batch_size=16, lr=3e-3, seed=0):
    torch.manual_seed(seed)
    model = GPT(vocab_size, block_size, config["n_layer"], config["n_head"], config["n_embd"])
    n = model.num_params()
    steps = steps_for_budget(budget_flops, n, batch_size, block_size)
    hist = train(model, train_ids, val_ids, block_size, batch_size, steps, lr, eval_every=steps, eval_iters=20,
                 seed=seed, weight_decay=0.0, log=lambda s: None)
    tokens = steps * batch_size * block_size
    return {"n_params": n, "steps": steps, "tokens": tokens, "flops": train_flops(n, tokens),
            "train_loss": hist[-1]["train_loss"], "val_loss": hist[-1]["val_loss"]}
