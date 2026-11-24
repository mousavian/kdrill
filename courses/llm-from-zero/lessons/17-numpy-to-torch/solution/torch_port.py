"""Lesson 17 - reference solution."""
import numpy as np
import torch
import torch.nn.functional as F


def to_torch(params):
    return {k: torch.tensor(np.array(v, dtype=np.float64), requires_grad=True) for k, v in params.items()}


def loss_fn(tp, X, Y):
    flat = tp["C"][X].reshape(X.shape[0], -1)
    h = torch.tanh(flat @ tp["W1"] + tp["b1"])
    logits = h @ tp["W2"] + tp["b2"]
    return F.cross_entropy(logits, Y)


def torch_grads(tp, X, Y):
    for p in tp.values():
        p.grad = None
    loss_fn(tp, X, Y).backward()
    return {k: p.grad.detach().numpy().copy() for k, p in tp.items()}


def max_abs_diff(a, b):
    return float(max(np.abs(np.asarray(a[k]) - np.asarray(b[k])).max() for k in a))


def sgd_step(tp, lr):
    with torch.no_grad():
        for p in tp.values():
            p -= lr * p.grad
            p.grad = None


def train_torch(np_params, X, Y, steps, lr, batch_size=32, seed=0):
    tp = to_torch(np_params)
    Xt, Yt = torch.from_numpy(np.asarray(X)), torch.from_numpy(np.asarray(Y))
    g = torch.Generator().manual_seed(seed)
    losses = []
    for _ in range(steps):
        idx = torch.randint(0, Xt.shape[0], (batch_size,), generator=g)
        loss = loss_fn(tp, Xt[idx], Yt[idx])
        loss.backward()
        losses.append(float(loss.item()))
        sgd_step(tp, lr)
    return tp, losses
