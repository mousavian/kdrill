"""Lesson 15 - reference solution."""
import numpy as np

import mlp_lm


def kaiming_scale(fan_in, gain=5 / 3):
    return gain / np.sqrt(fan_in)


def make_params(V, context, d_emb, hidden, seed=0, w1_scale=None, w2_scale=0.01):
    rng = np.random.default_rng(seed)
    fan_in = context * d_emb
    if w1_scale is None:
        w1_scale = kaiming_scale(fan_in)
    C = rng.normal(size=(V, d_emb))
    W1 = rng.normal(size=(fan_in, hidden)) * w1_scale
    W2 = rng.normal(size=(hidden, V)) * w2_scale
    return {"C": C, "W1": W1, "b1": np.zeros(hidden), "W2": W2, "b2": np.zeros(V)}


def hidden_stats(params, X):
    flat = params["C"][X].reshape(X.shape[0], -1)
    h = np.tanh(flat @ params["W1"] + params["b1"])
    return {"mean": float(h.mean()), "std": float(h.std()), "saturated": float((np.abs(h) > 0.97).mean())}


def update_ratio(params, grads, lr):
    return {k: float(np.log10(lr * grads[k].std() / params[k].std())) for k in params if params[k].ndim >= 2}


def lr_range_test(params, X, Y, lo=1e-3, hi=10.0, steps=60, batch_size=32, seed=0):
    p = {k: v.copy() for k, v in params.items()}
    rng = np.random.default_rng(seed)
    rows, first = [], None
    for i in range(steps):
        lr = lo * (hi / lo) ** (i / (steps - 1))
        idx = rng.integers(0, X.shape[0], batch_size)
        loss, cache = mlp_lm.forward(p, X[idx], Y[idx])
        rows.append((lr, loss))
        first = loss if first is None else first
        if not np.isfinite(loss) or loss > 4 * first:
            break
        g = mlp_lm.backward(p, cache)
        for k in p:
            p[k] -= lr * g[k]
    return rows


def suggest_lr(rows):
    ok = [(loss, lr) for lr, loss in rows if np.isfinite(loss)]
    return min(ok)[1] / 10
