"""Lesson 15 - initialisation, activation statistics and the learning rate. numpy only (no torch).

Builds on your mlp_lm.py (forward, backward) from lesson 14.
"""
import numpy as np

import mlp_lm


def kaiming_scale(fan_in, gain=5 / 3):
    """Standard deviation that keeps the signal's size through a tanh layer: gain / sqrt(fan_in)."""
    # TODO
    raise NotImplementedError


def make_params(V, context, d_emb, hidden, seed=0, w1_scale=None, w2_scale=0.01):
    """Like mlp_lm.init_params but with the scales as arguments. A dict with:
      C  ~ normal(0, 1) of shape (V, d_emb)
      W1 ~ normal(0, 1) * w1_scale, shape (context * d_emb, hidden);
           w1_scale None means kaiming_scale(context * d_emb)
      b1 = zeros(hidden)
      W2 ~ normal(0, 1) * w2_scale, shape (hidden, V)   (small: the first predictions are
           almost uniform, so the first loss is about ln V)
      b2 = zeros(V)
    Draw C, then W1, then W2 from rng = np.random.default_rng(seed), in that order."""
    # TODO
    raise NotImplementedError


def hidden_stats(params, X):
    """Statistics of the hidden layer's activations h = tanh(flat @ W1 + b1) on inputs X:
    {"mean": mean of h, "std": std of h, "saturated": share of entries with |h| > 0.97}.
    A saturated tanh has gradient near 0: those units barely learn."""
    # TODO
    raise NotImplementedError


def update_ratio(params, grads, lr):
    """For every parameter that is a matrix (ndim >= 2), log10(lr * std(grad) / std(param)):
    how big one update is relative to the weights. About -3 is a healthy rule of thumb.
    Return {name: ratio}."""
    # TODO
    raise NotImplementedError


def lr_range_test(params, X, Y, lo=1e-3, hi=10.0, steps=60, batch_size=32, seed=0):
    """Train on a COPY of params (the caller's params must stay untouched) for `steps` SGD
    steps while the learning rate grows geometrically from lo to hi:
    lr_i = lo * (hi / lo) ** (i / (steps - 1)). Minibatches come from
    rng.integers(0, N, batch_size) with rng = np.random.default_rng(seed).
    Record (lr_i, minibatch loss BEFORE the step i update) in a list and return it.
    Stop early, after recording, when the loss is not finite or exceeds 4 times the first loss."""
    # TODO
    raise NotImplementedError


def suggest_lr(rows):
    """From lr_range_test rows: the learning rate with the lowest finite loss, divided by 10
    (a step size below the edge of instability)."""
    # TODO
    raise NotImplementedError
