"""Lesson 13 - a neural bigram. numpy only (no torch).

The model: logits = W[x] (row x of a (V, V) weight matrix, i.e. a one-hot vector times W),
probabilities = softmax(logits), loss = cross-entropy against the next token y.
"""
import numpy as np


def make_xy(ids):
    """Inputs x = ids[:-1] and targets y = ids[1:], as int64 arrays."""
    # TODO
    raise NotImplementedError


def init_weights(V, seed=0, scale=0.01):
    """A (V, V) float64 matrix of normal(0, scale) numbers from np.random.default_rng(seed)."""
    # TODO
    raise NotImplementedError


def softmax(logits):
    """Row-wise softmax of a 2-D array, stable for huge logits (subtract the row max first)."""
    # TODO
    raise NotImplementedError


def forward(W, X, Y):
    """Return (loss, probs) for inputs X and targets Y (1-D int arrays of equal length).

    probs = softmax(W[X]), shape (n, V). loss = mean over the n samples of -log p[y].
    Compute the loss with the log-sum-exp trick, loss = mean(logsumexp(logits) - logits[y]),
    not as log(probs), so that logits of size +-1000 give a finite, correct loss.
    """
    # TODO
    raise NotImplementedError


def backward(probs, X, Y, V):
    """Gradient of the mean loss with respect to W, shape (V, V).

    Derive it yourself: for one sample the gradient of the loss wrt the logits is
    probs - onehot(y); the loss is a mean over n samples; row x of W receives the
    gradients of every sample whose input is x (np.add.at accumulates repeated rows).
    Rows of W that never occur in X get exactly zero. Do not modify `probs`.
    """
    # TODO
    raise NotImplementedError


def train(ids, V, steps=300, lr=30.0, seed=0):
    """Full-batch gradient descent on all (x, y) pairs of `ids`:
    W = init_weights(V, seed); repeat `steps` times: loss, probs = forward; dW = backward;
    W -= lr * dW. Return (W, losses) where losses[i] is the loss BEFORE step i."""
    # TODO
    raise NotImplementedError


def probs_from_weights(W):
    """The bigram table the weights represent: softmax of every row, shape (V, V)."""
    # TODO
    raise NotImplementedError


def mean_nll(W, ids):
    """Average negative log-likelihood of the transitions of `ids` under W."""
    # TODO
    raise NotImplementedError
