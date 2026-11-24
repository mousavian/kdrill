import math

import numpy as np
import pytest

import nbigram
from kdlib import kdtest
from kdlib.corpus import bundled_splits


def markov(V, n, seed):
    rng = np.random.default_rng(seed)
    T = rng.dirichlet(np.ones(V) * 0.7, size=V)
    seq, cur = [0], 0
    for _ in range(n):
        cur = int(rng.choice(V, p=T[cur])); seq.append(cur)
    return np.array(seq), T


def test_no_deep_learning_libraries():
    """numpy only: no torch, tensorflow, jax, sklearn, scipy"""
    kdtest.assert_no_imports("nbigram", {"torch", "tensorflow", "jax", "sklearn", "scipy"})


def test_make_xy_init_and_softmax():
    """make_xy shifts by one, init_weights is seeded normal noise, softmax rows sum to 1 and survive huge logits"""
    X, Y = nbigram.make_xy([3, 1, 2, 0])
    assert list(X) == [3, 1, 2] and list(Y) == [1, 2, 0] and X.dtype == np.int64
    W = nbigram.init_weights(5, seed=2, scale=0.5)
    assert W.shape == (5, 5) and np.array_equal(W, nbigram.init_weights(5, seed=2, scale=0.5)) and 0.1 < W.std() < 1.0
    p = nbigram.softmax(np.array([[1000.0, 1000.0, -1000.0], [0.0, 1.0, 2.0]]))
    assert np.allclose(p[0], [0.5, 0.5, 0]) and np.allclose(p.sum(axis=1), 1) and np.isfinite(p).all()


def test_forward_loss():
    """zero weights give loss ln V; the loss equals the mean of -ln p; huge logits stay finite and correct"""
    V = 6
    X, Y = nbigram.make_xy(np.random.default_rng(0).integers(0, V, 200))
    loss, probs = nbigram.forward(np.zeros((V, V)), X, Y)
    assert loss == pytest.approx(math.log(V)) and probs.shape == (len(X), V)
    W = np.random.default_rng(1).normal(size=(V, V))
    loss, probs = nbigram.forward(W, X, Y)
    assert loss == pytest.approx(-np.log(probs[np.arange(len(Y)), Y]).mean())
    big = np.zeros((V, V)); big[:, 0] = 900.0
    Xb, Yb = np.array([1, 2]), np.array([3, 3])
    loss, _ = nbigram.forward(big, Xb, Yb)
    assert np.isfinite(loss) and loss == pytest.approx(900.0, rel=1e-6), "compute the loss with log-sum-exp"


def test_gradient_matches_finite_differences():
    """backward equals numeric gradients of forward, including repeated inputs, and never touches probs"""
    V = 5
    rng = np.random.default_rng(4)
    X = np.array([0, 1, 1, 2, 2, 2, 4, 0, 1]); Y = rng.integers(0, V, len(X))
    W = rng.normal(size=(V, V))
    loss, probs = nbigram.forward(W, X, Y)
    keep = probs.copy()
    dW = nbigram.backward(probs, X, Y, V)
    assert np.array_equal(probs, keep), "backward must not modify probs"
    num = kdtest.numeric_grad(lambda: nbigram.forward(W, X, Y)[0], W)
    assert dW.shape == (V, V) and np.abs(dW - num).max() < 1e-7, np.abs(dW - num).max()
    assert np.all(dW[3] == 0), "row 3 never occurs as an input"


def test_training_reproduces_the_counting_model():
    """gradient descent on a random Markov chain ends up with the same table as counting (probabilities and loss)"""
    V = 8
    ids, T = markov(V, 8000, 5)
    W, losses = nbigram.train(ids, V, steps=400, lr=15.0, seed=0)
    assert len(losses) == 400 and losses[0] == pytest.approx(math.log(V), abs=0.01)
    assert all(a >= b - 1e-12 for a, b in zip(losses, losses[1:])), "loss must not go up with a sensible step size"
    counts = np.zeros((V, V)); np.add.at(counts, (ids[:-1], ids[1:]), 1)
    P_count = counts / counts.sum(axis=1, keepdims=True)
    P_nn = nbigram.probs_from_weights(W)
    assert np.allclose(P_nn.sum(axis=1), 1)
    assert np.abs(P_nn - P_count).max() < 0.03, np.abs(P_nn - P_count).max()
    count_loss = -np.log(P_count[ids[:-1], ids[1:]]).mean()
    assert nbigram.mean_nll(W, ids) == pytest.approx(count_loss, abs=0.01) and losses[-1] > count_loss - 1e-9


def test_seed_matters_for_init_only():
    """train is deterministic for a seed"""
    ids, _ = markov(5, 500, 1)
    a, _ = nbigram.train(ids, 5, steps=5, seed=1); b, _ = nbigram.train(ids, 5, steps=5, seed=1)
    assert np.array_equal(a, b)


def test_real_text_learns_something():
    """on the real characters the loss falls far below the uniform baseline, and validation loss is close to it"""
    tr, va, _ = bundled_splits()
    chars = sorted(set(tr) | set(va)); stoi = {c: i for i, c in enumerate(chars)}
    ti, vi = [stoi[c] for c in tr[:15000]], [stoi[c] for c in va[:10000]]
    W, losses = nbigram.train(ti, len(chars), steps=80, lr=60.0)
    assert losses[-1] < math.log(len(chars)) - 1.0
    assert nbigram.mean_nll(W, vi) < losses[-1] + 0.4
