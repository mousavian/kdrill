"""Lesson 11 - reference solution."""
import math

import numpy as np

from bigram import BigramModel


def nll(P, ids):
    ids = np.asarray(ids, dtype=np.int64)
    if len(ids) < 2:
        raise ValueError("need at least two ids")
    p = np.asarray(P)[ids[:-1], ids[1:]]
    if np.any(p <= 0):
        return float("inf")
    return float(-np.log(p).mean())


def perplexity(loss):
    return float("inf") if math.isinf(loss) else math.exp(loss)


def uniform_baseline(vocab_size):
    return math.log(vocab_size)


def bits_per_token(loss):
    return loss / math.log(2)


def evaluate(model, ids):
    loss = nll(model.probs(), ids)
    return loss, perplexity(loss)


def smoothing_sweep(train_ids, val_ids, vocab_size, candidates):
    rows = []
    for k in candidates:
        P = BigramModel(vocab_size, k).fit(train_ids).probs()
        rows.append((k, nll(P, train_ids), nll(P, val_ids)))
    return rows


def best_smoothing(rows):
    return min(rows, key=lambda r: (r[2], r[0]))[0]
