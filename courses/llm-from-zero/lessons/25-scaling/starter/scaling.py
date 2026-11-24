"""Lesson 25 - a small scaling experiment (PyTorch + numpy + matplotlib for the saved plot only).
Uses GPT (gpt.py, lesson 21) and train/evaluate (loop.py, lesson 18).
"""
import math

import numpy as np
import torch

from gpt import GPT
from loop import evaluate, train


def train_flops(n_params, tokens):
    """Training compute in FLOPs by the standard estimate: 6 * N * D (forward and backward cost
    about 6 floating point operations per parameter per token). Return a float."""
    # TODO
    raise NotImplementedError


def steps_for_budget(budget_flops, n_params, batch_size, block_size):
    """Number of optimizer steps that spend about `budget_flops`: each step processes
    batch_size * block_size tokens. round() the result, and never return less than 1."""
    # TODO
    raise NotImplementedError


def fit_power_law(xs, ys):
    """Least-squares fit of y = a * x ** b in log-log space (np.polyfit on log x, log y, degree 1).
    Return (a, b). ValueError for fewer than 2 points or any non-positive value."""
    # TODO
    raise NotImplementedError


def predict_power_law(a, b, x):
    """a * x ** b"""
    # TODO
    raise NotImplementedError


def plot_curves(curves, path, xlabel="compute (FLOPs)", ylabel="validation loss", title=""):
    """Save a PNG line plot. `curves` is a dict label -> list of (x, y) points. Use matplotlib's
    Agg backend (import matplotlib; matplotlib.use("Agg") inside the function), a logarithmic x axis,
    one line with markers per curve, a legend, axis labels and the title; close the figure afterwards.
    Create the parent directory if needed. Return `path`."""
    # TODO
    raise NotImplementedError


def run_one(config, budget_flops, train_ids, val_ids, vocab_size, block_size=32, batch_size=16, lr=3e-3, seed=0):
    """Train one model on a compute budget and return its result.

    config: dict with n_layer, n_head, n_embd. Build GPT(vocab_size, block_size, ...) after
    torch.manual_seed(seed); N = model.num_params(); steps = steps_for_budget(...); train with
    loop.train (AdamW, no weight decay, eval_every=steps so there is one evaluation at the start
    and one at the end, eval_iters=20, log=lambda s: None).
    Return {"n_params": N, "steps": steps, "tokens": steps * batch_size * block_size,
            "flops": train_flops(N, tokens), "train_loss": final train loss, "val_loss": final val loss}
    (final = the history row after the last step)."""
    # TODO
    raise NotImplementedError
