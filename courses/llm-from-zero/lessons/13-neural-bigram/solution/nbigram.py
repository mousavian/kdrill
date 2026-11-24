"""Lesson 13 - reference solution."""
import numpy as np


def make_xy(ids):
    ids = np.asarray(ids, dtype=np.int64)
    return ids[:-1], ids[1:]


def init_weights(V, seed=0, scale=0.01):
    return np.random.default_rng(seed).normal(0.0, scale, size=(V, V))


def softmax(logits):
    z = logits - logits.max(axis=1, keepdims=True)
    e = np.exp(z)
    return e / e.sum(axis=1, keepdims=True)


def forward(W, X, Y):
    logits = W[X]
    m = logits.max(axis=1, keepdims=True)
    lse = (m + np.log(np.exp(logits - m).sum(axis=1, keepdims=True)))[:, 0]
    loss = float((lse - logits[np.arange(len(Y)), Y]).mean())
    return loss, softmax(logits)


def backward(probs, X, Y, V):
    n = len(Y)
    dlogits = probs.copy()
    dlogits[np.arange(n), Y] -= 1.0
    dlogits /= n
    dW = np.zeros((V, V))
    np.add.at(dW, X, dlogits)
    return dW


def train(ids, V, steps=300, lr=30.0, seed=0):
    X, Y = make_xy(ids)
    W = init_weights(V, seed)
    losses = []
    for _ in range(steps):
        loss, probs = forward(W, X, Y)
        losses.append(loss)
        W -= lr * backward(probs, X, Y, V)
    return W, losses


def probs_from_weights(W):
    return softmax(W)


def mean_nll(W, ids):
    X, Y = make_xy(ids)
    return forward(W, X, Y)[0]
