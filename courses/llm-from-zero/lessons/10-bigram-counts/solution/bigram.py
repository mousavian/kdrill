"""Lesson 10 - reference solution."""
import numpy as np


class BigramModel:
    def __init__(self, vocab_size, smoothing=0.0):
        self.vocab_size = vocab_size
        self.smoothing = smoothing
        self.counts = np.zeros((vocab_size, vocab_size), dtype=np.float64)

    def fit(self, ids):
        ids = np.asarray(ids, dtype=np.int64)
        V = self.vocab_size
        if len(ids) < 2:
            self.counts = np.zeros((V, V))
        else:
            pair = ids[:-1] * V + ids[1:]
            self.counts = np.bincount(pair, minlength=V * V).reshape(V, V).astype(np.float64)
        return self

    def probs(self):
        c = self.counts + self.smoothing
        tot = c.sum(axis=1, keepdims=True)
        out = np.empty_like(c)
        empty = (tot[:, 0] == 0)
        out[~empty] = c[~empty] / tot[~empty]
        out[empty] = 1.0 / self.vocab_size
        return out

    def prob(self, a, b):
        return float(self.probs()[a, b])

    def top_next(self, a, k=3):
        row = self.probs()[a]
        order = sorted(range(self.vocab_size), key=lambda j: (-row[j], j))
        return [int(j) for j in order[:k]]

    def sample(self, n, start=0, seed=0):
        P = self.probs()
        rng = np.random.default_rng(seed)
        out, cur = [], start
        for _ in range(n):
            cur = int(rng.choice(self.vocab_size, p=P[cur]))
            out.append(cur)
        return out
