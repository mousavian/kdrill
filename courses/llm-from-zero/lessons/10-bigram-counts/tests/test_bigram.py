import time

import numpy as np
import pytest

from bigram import BigramModel
from kdlib import kdtest
from kdlib.corpus import bundled_splits


def test_no_deep_learning_libraries():
    """this model is counting: numpy only, no torch / tensorflow / sklearn / scipy"""
    kdtest.assert_no_imports("bigram", {"torch", "tensorflow", "sklearn", "scipy", "jax"})


def test_counts():
    """counts[a, b] is how often b follows a; refitting replaces the counts; short input gives zeros"""
    m = BigramModel(4).fit([0, 1, 1, 2, 1, 2, 3])
    expect = np.zeros((4, 4)); expect[0, 1] = 1; expect[1, 1] = 1; expect[1, 2] = 2; expect[2, 1] = 1; expect[2, 3] = 1
    assert np.array_equal(m.counts, expect)
    assert m.fit([3, 3]).counts[3, 3] == 1 and m.counts.sum() == 1
    assert BigramModel(4).fit([2]).counts.sum() == 0 and BigramModel(4).fit([]).counts.sum() == 0


def test_probabilities_and_smoothing():
    """rows are probability distributions; add-k smoothing and uniform rows for unseen contexts"""
    m = BigramModel(3).fit([0, 1, 0, 1, 0, 2])
    P = m.probs()
    assert np.allclose(P.sum(axis=1), 1) and P[0, 1] == pytest.approx(2 / 3) and P[0, 2] == pytest.approx(1 / 3)
    assert np.allclose(P[2], 1 / 3), "token 2 was never a context: uniform row"
    s = BigramModel(3, smoothing=1.0).fit([0, 1, 0, 1, 0, 2]).probs()
    assert s[0, 1] == pytest.approx(3 / 6) and s[0, 0] == pytest.approx(1 / 6) and s[2, 2] == pytest.approx(1 / 3)
    assert m.prob(0, 1) == pytest.approx(2 / 3)


def test_top_next():
    """top_next lists the k most probable successors, ties broken by the lower id"""
    m = BigramModel(5).fit([0, 3, 0, 1, 0, 3, 0, 4, 0, 1])
    assert m.top_next(0, 2) == [1, 3] and m.top_next(0, 3) == [1, 3, 4] and m.top_next(0, 1) == [1]
    assert all(type(i) is int for i in m.top_next(0))


def test_sampling_follows_a_deterministic_chain():
    """a model of the cycle 0,1,2,0,1,2... samples the cycle; the start token is not returned; seeds are respected"""
    m = BigramModel(3).fit([0, 1, 2] * 20)
    out = m.sample(9, start=0, seed=4)
    assert out == [1, 2, 0, 1, 2, 0, 1, 2, 0] and all(type(i) is int for i in out)
    m2 = BigramModel(4, smoothing=1.0).fit([0, 1, 2, 3, 1, 1, 2, 0] * 10)
    assert m2.sample(50, 1, seed=7) == m2.sample(50, 1, seed=7) and m2.sample(50, 1, seed=7) != m2.sample(50, 1, seed=8)
    assert m.sample(0) == []


def test_sampling_frequencies_match_probabilities():
    """over many samples the next-token frequencies match the model's probabilities"""
    rnd = np.random.default_rng(0)
    seq = rnd.choice(4, size=4000, p=[0.1, 0.2, 0.3, 0.4])
    m = BigramModel(4, smoothing=0.5).fit(seq)
    out = np.array(m.sample(30000, start=0, seed=1))
    prev = np.concatenate([[0], out[:-1]])
    P = m.probs()
    for a in range(4):
        sel = out[prev == a]
        assert len(sel) > 500
        freq = np.bincount(sel, minlength=4) / len(sel)
        assert np.abs(freq - P[a]).max() < 0.03, (a, freq, P[a])


def test_fast_on_a_million_ids():
    """fit counts a million ids without a Python loop over the data"""
    ids = np.random.default_rng(1).integers(0, 60, size=1_000_000)
    t0 = time.time()
    m = BigramModel(60).fit(ids)
    assert time.time() - t0 < 2.0 and m.counts.sum() == 999_999


def test_real_text_looks_like_english():
    """trained on the real training split, 'q' is followed by 'u' and a space is followed mostly by a letter"""
    tr, _, _ = bundled_splits()
    chars = sorted(set(tr)); stoi = {c: i for i, c in enumerate(chars)}
    m = BigramModel(len(chars)).fit([stoi[c] for c in tr])
    assert chars[m.top_next(stoi["q"], 1)[0]] == "u"
    assert m.prob(stoi["t"], stoi["h"]) > 0.3
    s = "".join(chars[i] for i in m.sample(400, stoi[" "], seed=3))
    assert len(s) == 400 and sum(c == " " for c in s) > 30
