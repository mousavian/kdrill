"""Lesson 16 - layer normalisation by hand. numpy only (no torch)."""
import numpy as np


def layernorm_forward(x, gamma, beta, eps=1e-5):
    """Normalise every ROW of x (shape (N, D)) over its D features:
        mean = x.mean(axis=1), var = x.var(axis=1)   (biased variance: divide by D)
        xhat = (x - mean) / sqrt(var + eps)
        out  = gamma * xhat + beta                    (gamma, beta: shape (D,))
    Return (out, cache) where cache holds what layernorm_backward needs."""
    # TODO
    raise NotImplementedError


def layernorm_backward(dout, cache):
    """Gradients of a loss wrt the inputs, given dout = d loss / d out (shape (N, D)).
    Return (dx, dgamma, dbeta).

    dbeta = dout summed over rows, dgamma = (dout * xhat) summed over rows. For dx, with
    dxhat = dout * gamma and D features per row:
        dx = (1 / sqrt(var + eps)) * (dxhat - mean(dxhat) - xhat * mean(dxhat * xhat))
    where the means are taken over the features (axis=1). Derive it, or at least convince
    yourself with the numeric check why mean and xhat terms appear."""
    # TODO
    raise NotImplementedError


def deep_pre_activation_stds(depth, width, weight_scale, use_layernorm, seed=0, n=256):
    """Push random inputs through `depth` layers  h = tanh(LN?(h @ W)),  W ~ normal(0, weight_scale^2)
    of shape (width, width), x ~ normal(0, 1) of shape (n, width) (draw x first, then W per layer
    from rng = np.random.default_rng(seed)). If use_layernorm, apply layernorm_forward
    (gamma = ones, beta = zeros) to h @ W BEFORE the tanh. Return the list of std of the
    pre-activation (h @ W, after layer norm when used) for each layer."""
    # TODO
    raise NotImplementedError
