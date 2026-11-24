import math
import warnings

import numpy as np
import pytest

import metrics
from bigram import BigramModel
from kdlib import kdtest
from kdlib.corpus import bundled_splits


def test_no_deep_learning_libraries():
    """numpy only: no torch, tensorflow, sklearn, scipy"""
    kdtest.assert_no_imports("metrics", {"torch", "tensorflow", "sklearn", "scipy", "jax"})


def test_nll_exact_values():
    """nll is the mean of -ln P over the transitions; the uniform model scores ln V"""
    P = np.array([[0.5, 0.5], [0.25, 0.75]])
    ids = [0, 1, 1, 0]   # P[0,1]=.5, P[1,1]=.75, P[1,0]=.25
    assert metrics.nll(P, ids) == pytest.approx(-(math.log(.5) + math.log(.75) + math.log(.25)) / 3)
    V = 7
    ids = np.random.default_rng(0).integers(0, V, 500)
    assert metrics.nll(np.full((V, V), 1 / V), ids) == pytest.approx(math.log(V))
    assert metrics.uniform_baseline(V) == pytest.approx(math.log(V))
    with pytest.raises(ValueError):
        metrics.nll(P, [1])


def test_zero_probability_is_infinite_loss_quietly():
    """a transition the model gave probability 0 makes the loss inf, without nan, exceptions or warnings"""
    P = np.array([[1.0, 0.0], [0.5, 0.5]])
    with warnings.catch_warnings():
        warnings.simplefilter("error")
        assert metrics.nll(P, [0, 1]) == float("inf")
        assert metrics.perplexity(float("inf")) == float("inf")


def test_perplexity_and_bits():
    """perplexity is exp(loss); the uniform model over V tokens has perplexity V; bits = nats / ln 2"""
    assert metrics.perplexity(0.0) == 1.0 and metrics.perplexity(math.log(27)) == pytest.approx(27)
    assert metrics.bits_per_token(math.log(8)) == pytest.approx(3.0)


def test_evaluate():
    """evaluate returns (loss, perplexity) of a model on ids"""
    m = BigramModel(3, 1.0).fit([0, 1, 2, 0, 1, 2, 0, 0])
    loss, ppl = metrics.evaluate(m, [0, 1, 2, 0, 1])
    assert loss == pytest.approx(metrics.nll(m.probs(), [0, 1, 2, 0, 1])) and ppl == pytest.approx(math.exp(loss))


def test_memorising_the_training_data_scores_badly_on_new_data():
    """with no smoothing the training loss is lowest but validation loss is infinite or worse; selection by validation picks k > 0"""
    rng = np.random.default_rng(3)
    V = 30
    # a sparse random bigram chain: few transitions per row, so unsmoothed train/val pairs differ
    trans = np.zeros((V, V))
    for a in range(V):
        trans[a, rng.choice(V, 6, replace=False)] = rng.dirichlet(np.ones(6))
    def run(n):
        out, cur = [0], 0
        for _ in range(n):
            cur = int(rng.choice(V, p=trans[cur])); out.append(cur)
        return out
    tr, va = run(1500), run(1500)
    rows = metrics.smoothing_sweep(tr, va, V, [0.0, 0.01, 0.1, 0.5, 2.0])
    assert [r[0] for r in rows] == [0.0, 0.01, 0.1, 0.5, 2.0]
    train_losses = [r[1] for r in rows]
    assert train_losses[0] == min(train_losses), "training loss rewards memorising"
    assert rows[0][2] > rows[2][2], "validation loss must punish k = 0 here"
    k = metrics.best_smoothing(rows)
    assert k in (0.01, 0.1) and k == min(rows, key=lambda r: r[2])[0]
    assert metrics.best_smoothing([(1.0, 2.0, 3.0), (0.5, 9.0, 3.0), (2.0, 1.0, 4.0)]) == 0.5, "ties go to the smaller k"


def test_real_text_numbers():
    """on the real text: char bigram validation loss is well below the uniform baseline, perplexity matches"""
    tr, va, _ = bundled_splits()
    chars = sorted(set(tr) | set(va)); stoi = {c: i for i, c in enumerate(chars)}
    ti, vi = [stoi[c] for c in tr], [stoi[c] for c in va]
    rows = metrics.smoothing_sweep(ti, vi, len(chars), [0.0, 0.1, 1.0])
    base = metrics.uniform_baseline(len(chars))
    best = min(r[2] for r in rows)
    assert 2.0 < best < 3.0 < base, (best, base)
    assert rows[0][2] == float("inf") or rows[0][2] > best
    assert metrics.perplexity(best) == pytest.approx(math.exp(best))
