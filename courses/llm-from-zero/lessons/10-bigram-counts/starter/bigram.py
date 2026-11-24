"""Lesson 10 - a counting bigram language model. numpy only (no torch)."""
import numpy as np


class BigramModel:
    """P(next token | current token), estimated by counting.

    `ids` everywhere is a sequence of token ids in range(vocab_size) (list or array).
    """

    def __init__(self, vocab_size, smoothing=0.0):
        self.vocab_size = vocab_size
        self.smoothing = smoothing
        self.counts = np.zeros((vocab_size, vocab_size), dtype=np.float64)

    def fit(self, ids):
        """Count every adjacent pair: counts[a, b] = how often b follows a in `ids`.
        Replaces earlier counts. Must be fast for a million ids (no Python loop over
        the data: np.add.at or np.bincount on a * V + b). Return self."""
        # TODO
        raise NotImplementedError

    def probs(self):
        """(V, V) matrix P with P[a, b] = (counts[a, b] + smoothing) / sum_b(counts[a, b] + smoothing).
        A row whose total is 0 (a token never seen as context, no smoothing) is uniform: 1 / V."""
        # TODO
        raise NotImplementedError

    def prob(self, a, b):
        """P(b | a)."""
        # TODO
        raise NotImplementedError

    def top_next(self, a, k=3):
        """The k most probable next ids after `a`, most probable first, ties by lower id
        (a list of ints)."""
        # TODO
        raise NotImplementedError

    def sample(self, n, start=0, seed=0):
        """Generate n ids (a list of Python ints). The first is drawn from P[start], the
        next from the row of the one before, and so on; `start` itself is not returned.
        Use np.random.default_rng(seed) so a seed gives the same text every time."""
        # TODO
        raise NotImplementedError
