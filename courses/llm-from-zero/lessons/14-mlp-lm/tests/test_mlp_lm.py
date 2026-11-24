import math

import numpy as np
import pytest

import mlp_lm
from kdlib import kdtest
from kdlib.corpus import bundled_splits


def small(seed=0, V=7, ctx=3, d=4, h=5):
    p = mlp_lm.init_params(V, ctx, d, h, seed)
    rng = np.random.default_rng(seed + 100)
    for k in ("b1", "b2"):
        p[k] = rng.normal(size=p[k].shape) * 0.3        # non-zero biases so their gradients are tested for real
    p["W2"] = rng.normal(size=p["W2"].shape) * 0.5
    return p


def batch(V=7, ctx=3, n=9, seed=1):
    rng = np.random.default_rng(seed)
    X = rng.integers(0, V, (n, ctx)); X[1] = X[0]; X[2, 0] = X[0, 1]    # repeated tokens, inside and across rows
    return X, rng.integers(0, V, n)


def test_no_deep_learning_libraries():
    """numpy only: no torch, tensorflow, jax, sklearn, scipy"""
    kdtest.assert_no_imports("mlp_lm", {"torch", "tensorflow", "jax", "sklearn", "scipy"})


def test_forward_matches_a_reference():
    """forward gives the textbook loss for embeddings -> tanh layer -> softmax, and ln V for an untrained model"""
    p = small()
    X, Y = batch()
    loss, cache = mlp_lm.forward(p, X, Y)
    emb = p["C"][X].reshape(len(X), -1)
    logits = np.tanh(emb @ p["W1"] + p["b1"]) @ p["W2"] + p["b2"]
    pr = np.exp(logits - logits.max(1, keepdims=True)); pr /= pr.sum(1, keepdims=True)
    assert loss == pytest.approx(-np.log(pr[np.arange(len(Y)), Y]).mean())
    p0 = mlp_lm.init_params(27, 3, 8, 32, seed=2)
    X0, Y0 = batch(27, 3, 300, 3)
    assert abs(mlp_lm.forward(p0, X0, Y0)[0] - math.log(27)) < 0.3


def test_forward_is_stable_for_huge_logits():
    """huge logits give a finite, correct loss"""
    p = small()
    p["b2"] = np.zeros(7); p["b2"][0] = 800.0
    X, Y = batch(n=4)
    Y[:] = 3
    loss, _ = mlp_lm.forward(p, X, Y)
    assert np.isfinite(loss) and loss > 700


@pytest.mark.parametrize("key", ["C", "W1", "b1", "W2", "b2"])
def test_gradients_match_finite_differences(key):
    """backward equals numeric gradients for every parameter (with repeated tokens), and changes nothing"""
    p = small(seed=3)
    X, Y = batch()
    loss, cache = mlp_lm.forward(p, X, Y)
    before = {k: v.copy() for k, v in p.items()}
    g = mlp_lm.backward(p, cache)
    assert set(g) == set(p) and all(g[k].shape == p[k].shape for k in p)
    assert all(np.array_equal(p[k], before[k]) for k in p), "backward must not modify params"
    num = kdtest.numeric_grad(lambda: mlp_lm.forward(p, X, Y)[0], p[key])
    err = np.abs(g[key] - num).max()
    assert err < 1e-6, "gradient of %s is wrong (max error %.2e)" % (key, err)


def test_make_dataset_and_train_is_deterministic():
    """make_dataset windows are right; train is seeded, in place, and lowers the loss"""
    X, Y = mlp_lm.make_dataset([5, 6, 7, 8, 9], 2)
    assert X.tolist() == [[5, 6], [6, 7], [7, 8]] and Y.tolist() == [7, 8, 9]
    ids = np.tile([0, 1, 2, 3], 80)
    X, Y = mlp_lm.make_dataset(ids, 2)
    a = mlp_lm.init_params(4, 2, 3, 8, seed=1); b = mlp_lm.init_params(4, 2, 3, 8, seed=1)
    la = mlp_lm.train(a, X, Y, steps=60, lr=0.3, batch_size=16, seed=5)
    lb = mlp_lm.train(b, X, Y, steps=60, lr=0.3, batch_size=16, seed=5)
    assert la == lb and all(np.array_equal(a[k], b[k]) for k in a) and len(la) == 60
    assert np.mean(la[-10:]) < np.mean(la[:10])


def test_evaluate_loss_is_the_mean_over_everything():
    """evaluate_loss in chunks of unequal size equals the loss over all rows at once"""
    p = small(seed=4, V=9)
    rng = np.random.default_rng(0)
    X, Y = rng.integers(0, 9, (103, 3)), rng.integers(0, 9, 103)
    assert mlp_lm.evaluate_loss(p, X, Y, batch=10) == pytest.approx(mlp_lm.forward(p, X, Y)[0])


def test_learns_a_pattern_and_samples_it():
    """a model trained on a repeating pattern predicts the next token with high probability; sample follows next_probs"""
    ids = np.tile([0, 1, 2], 200)
    X, Y = mlp_lm.make_dataset(ids, 2)
    p = mlp_lm.init_params(3, 2, 3, 12, seed=0)
    mlp_lm.train(p, X, Y, steps=600, lr=0.5, batch_size=32, seed=0)
    pr = mlp_lm.next_probs(p, [0, 1])
    assert pr.shape == (3,) and pr.sum() == pytest.approx(1) and pr[2] > 0.95
    forced = {k: v.copy() for k, v in p.items()}
    forced["b2"] = np.array([0.0, 500.0, 0.0])
    out = mlp_lm.sample(forced, [0, 2, 0], 6, seed=1)
    assert out == [1] * 6 and all(type(i) is int for i in out)
    q = small(seed=6)
    assert mlp_lm.sample(q, [1, 2, 3], 12, seed=3) == mlp_lm.sample(q, [1, 2, 3], 12, seed=3)
    assert mlp_lm.sample(q, [1, 2, 3], 0) == []


def test_beats_the_bigram_on_real_text():
    """trained on real characters, the context-3 MLP gets a clearly lower validation loss than the best bigram"""
    tr, va, _ = bundled_splits()
    chars = sorted(set(tr) | set(va)); stoi = {c: i for i, c in enumerate(chars)}
    ti = np.array([stoi[c] for c in tr[:150000]]); vi = np.array([stoi[c] for c in va[:30000]])
    V = len(chars)
    counts = np.zeros((V, V)); np.add.at(counts, (ti[:-1], ti[1:]), 1)
    P = (counts + 0.1) / (counts + 0.1).sum(1, keepdims=True)
    bigram = -np.log(P[vi[:-1], vi[1:]]).mean()
    X, Y = mlp_lm.make_dataset(ti, 3)
    Xv, Yv = mlp_lm.make_dataset(vi, 3)
    p = mlp_lm.init_params(V, 3, 8, 64, seed=0)
    mlp_lm.train(p, X, Y, steps=4000, lr=0.3, batch_size=64, seed=0)
    mlp_lm.train(p, X, Y, steps=2000, lr=0.03, batch_size=64, seed=1)
    val = mlp_lm.evaluate_loss(p, Xv, Yv)
    assert val < bigram - 0.12, "MLP %.3f vs bigram %.3f" % (val, bigram)
