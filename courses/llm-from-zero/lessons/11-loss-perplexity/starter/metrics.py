"""Lesson 11 - loss and perplexity. numpy only (no torch).

Uses BigramModel from lesson 10: model.probs() is a (V, V) matrix P[a, b] = P(b | a).
"""
import math

import numpy as np

from bigram import BigramModel


def nll(P, ids):
    """Average negative log-likelihood, in nats, of the transitions ids[i] -> ids[i+1]
    under the (V, V) probability matrix P. (len(ids) - 1 transitions.)
    A transition with probability 0 makes the result float('inf'): no nan, no exception,
    no numpy warning. Fewer than 2 ids: raise ValueError."""
    # TODO
    raise NotImplementedError


def perplexity(loss):
    """exp(loss); infinite loss gives float('inf'). It is the 'effective number of
    equally likely choices' per token."""
    # TODO
    raise NotImplementedError


def uniform_baseline(vocab_size):
    """The loss of a model that knows nothing: every token equally likely."""
    # TODO
    raise NotImplementedError


def bits_per_token(loss):
    """The same loss in bits (divide nats by ln 2)."""
    # TODO
    raise NotImplementedError


def evaluate(model, ids):
    """(loss, perplexity) of a model with .probs() on ids."""
    # TODO
    raise NotImplementedError


def smoothing_sweep(train_ids, val_ids, vocab_size, candidates):
    """For every candidate smoothing k fit BigramModel(vocab_size, k) on train_ids and
    return a list of (k, train_loss, val_loss) in the order of `candidates`."""
    # TODO
    raise NotImplementedError


def best_smoothing(rows):
    """From smoothing_sweep rows, the k with the lowest VALIDATION loss (ties: smaller k).
    Choosing by training loss would always pick the smallest k: that is the lesson."""
    # TODO
    raise NotImplementedError
