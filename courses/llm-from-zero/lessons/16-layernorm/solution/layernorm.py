"""Lesson 16 - reference solution."""
import numpy as np


def layernorm_forward(x, gamma, beta, eps=1e-5):
    mean = x.mean(axis=1, keepdims=True)
    var = x.var(axis=1, keepdims=True)
    rstd = 1.0 / np.sqrt(var + eps)
    xhat = (x - mean) * rstd
    return gamma * xhat + beta, (xhat, rstd, gamma)


def layernorm_backward(dout, cache):
    xhat, rstd, gamma = cache
    dxhat = dout * gamma
    dx = rstd * (dxhat - dxhat.mean(axis=1, keepdims=True) - xhat * (dxhat * xhat).mean(axis=1, keepdims=True))
    return dx, (dout * xhat).sum(axis=0), dout.sum(axis=0)


def deep_pre_activation_stds(depth, width, weight_scale, use_layernorm, seed=0, n=256):
    rng = np.random.default_rng(seed)
    h = rng.normal(size=(n, width))
    out = []
    for _ in range(depth):
        W = rng.normal(size=(width, width)) * weight_scale
        z = h @ W
        if use_layernorm:
            z, _ = layernorm_forward(z, np.ones(width), np.zeros(width))
        out.append(float(z.std()))
        h = np.tanh(z)
    return out
