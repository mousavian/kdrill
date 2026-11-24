import numpy as np
import pytest

import layernorm as ln
from kdlib import kdtest


def test_no_deep_learning_libraries():
    """numpy only: no torch, tensorflow, jax"""
    kdtest.assert_no_imports("layernorm", {"torch", "tensorflow", "jax", "sklearn", "scipy"})


def test_forward_statistics_and_reference():
    """each row of the normalised output has mean 0 and variance 1 (gamma=1, beta=0); gamma and beta then scale and shift"""
    rng = np.random.default_rng(0)
    x = rng.normal(size=(6, 10)) * rng.uniform(0.1, 20, size=(6, 1)) + rng.uniform(-30, 30, size=(6, 1))
    out, _ = ln.layernorm_forward(x, np.ones(10), np.zeros(10))
    assert np.allclose(out.mean(axis=1), 0, atol=1e-9) and np.allclose(out.var(axis=1), 1, atol=1e-3)
    g, b = rng.normal(size=10), rng.normal(size=10)
    out2, _ = ln.layernorm_forward(x, g, b)
    ref = (x - x.mean(1, keepdims=True)) / np.sqrt(x.var(1, keepdims=True) + 1e-5) * g + b
    assert np.allclose(out2, ref)
    assert not np.allclose(ln.layernorm_forward(x, np.ones(10), np.zeros(10), eps=1.0)[0], out), "eps must be used"


def test_scale_invariance():
    """multiplying a row by a constant (or adding one) does not change the output: that is what normalisation is for"""
    rng = np.random.default_rng(1)
    x = rng.normal(size=(4, 8))
    a, _ = ln.layernorm_forward(x, np.ones(8), np.zeros(8), eps=1e-12)
    b, _ = ln.layernorm_forward(x * 50 + 7, np.ones(8), np.zeros(8), eps=1e-12)
    assert np.allclose(a, b, atol=1e-6)


@pytest.mark.parametrize("which", ["x", "gamma", "beta"])
def test_backward_matches_finite_differences(which):
    """dx, dgamma and dbeta equal numeric gradients of a random linear function of the output"""
    rng = np.random.default_rng(2)
    x = rng.normal(size=(5, 7)) * 2 + 1
    gamma, beta = rng.normal(size=7), rng.normal(size=7)
    w = rng.normal(size=(5, 7))
    def loss():
        out, _ = ln.layernorm_forward(x, gamma, beta)
        return float((out * w).sum())
    out, cache = ln.layernorm_forward(x, gamma, beta)
    dx, dgamma, dbeta = ln.layernorm_backward(w.copy(), cache)
    got = {"x": dx, "gamma": dgamma, "beta": dbeta}[which]
    target = {"x": x, "gamma": gamma, "beta": beta}[which]
    num = kdtest.numeric_grad(loss, target)
    assert got.shape == target.shape and np.abs(got - num).max() < 1e-6, "gradient wrt %s is wrong (max error %.2e)" % (which, np.abs(got - num).max())


def test_backward_does_not_modify_inputs():
    """backward leaves dout and the cache untouched"""
    rng = np.random.default_rng(3)
    x = rng.normal(size=(3, 4))
    out, cache = ln.layernorm_forward(x, np.ones(4), np.zeros(4))
    dout = rng.normal(size=(3, 4)); keep = dout.copy()
    ln.layernorm_backward(dout, cache)
    assert np.array_equal(dout, keep)
    ln.layernorm_backward(dout, cache)   # callable twice
    assert np.array_equal(dout, keep)


def test_signal_size_through_a_deep_stack():
    """without layer norm the signal vanishes or saturates with the weight scale; with it, every layer sees std 1"""
    for scale in (0.02, 0.1, 3.0):
        normed = ln.deep_pre_activation_stds(15, 64, scale, True, seed=1)
        assert len(normed) == 15 and all(0.97 < s < 1.03 for s in normed), (scale, normed[:3])
    tiny = ln.deep_pre_activation_stds(15, 64, 0.02, False, seed=1)
    assert tiny[-1] < 1e-3 * tiny[0], "a small init makes the signal vanish through depth"
    ok = ln.deep_pre_activation_stds(15, 64, 5 / 3 / 8, False, seed=1)
    assert 0.3 < ok[-1] < 3.0, "the Kaiming-scaled network keeps a healthy signal without layer norm"
    assert ln.deep_pre_activation_stds(3, 8, 0.5, False, seed=4) == ln.deep_pre_activation_stds(3, 8, 0.5, False, seed=4)
