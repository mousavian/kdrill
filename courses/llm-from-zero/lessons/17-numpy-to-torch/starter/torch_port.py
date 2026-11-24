"""Lesson 17 - the MLP language model in PyTorch, gradients by autograd.

Do NOT import mlp_lm here: the point is that autograd reproduces what you wrote by hand.
"""
import numpy as np
import torch
import torch.nn.functional as F


def to_torch(params):
    """Turn a dict of numpy arrays (C, W1, b1, W2, b2 as in lesson 14) into a dict of torch
    tensors: dtype float64, requires_grad=True, and COPIES (changing a tensor must not
    change the numpy array)."""
    # TODO
    raise NotImplementedError


def loss_fn(tp, X, Y):
    """The lesson-14 model with torch operations. X is a (N, context) LongTensor, Y a (N,)
    LongTensor. emb = tp["C"][X] -> flatten -> tanh(flat @ W1 + b1) -> @ W2 + b2 -> mean
    cross-entropy (F.cross_entropy takes logits and class indices). Return a scalar tensor."""
    # TODO
    raise NotImplementedError


def torch_grads(tp, X, Y):
    """Gradients of loss_fn for every tensor in tp, as a dict of numpy float64 arrays (copies).
    Clear old gradients first (p.grad = None), so calling it twice gives the same answer."""
    # TODO
    raise NotImplementedError


def max_abs_diff(a, b):
    """Largest absolute difference between two dicts of arrays with the same keys: the
    maximum over all keys and entries (a float)."""
    # TODO
    raise NotImplementedError


def sgd_step(tp, lr):
    """In place: p -= lr * p.grad for every tensor, under torch.no_grad(), then set every
    p.grad to None. The tensors must stay leaf tensors with requires_grad=True."""
    # TODO
    raise NotImplementedError


def train_torch(np_params, X, Y, steps, lr, batch_size=32, seed=0):
    """Minibatch SGD with torch. X, Y are numpy arrays. Use tp = to_torch(np_params), a
    torch.Generator seeded with `seed` for the batch indices
    (torch.randint(0, N, (batch_size,), generator=g)), loss_fn, loss.backward() and sgd_step.
    Return (tp, losses) with losses a list of Python floats."""
    # TODO
    raise NotImplementedError
