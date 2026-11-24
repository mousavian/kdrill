import numpy as np
import pytest
import torch

import torch_port as tp
from kdlib import kdtest


def ref_params(V=9, ctx=3, d=4, h=6, seed=0):
    rng = np.random.default_rng(seed)
    return {"C": rng.normal(size=(V, d)), "W1": rng.normal(size=(ctx * d, h)) * 0.5, "b1": rng.normal(size=h) * 0.2,
            "W2": rng.normal(size=(h, V)) * 0.5, "b2": rng.normal(size=V) * 0.2}


def ref_loss_and_grads(p, X, Y):
    """independent numpy reference (forward and hand-derived backward)"""
    N, ctx = X.shape
    flat = p["C"][X].reshape(N, -1)
    h = np.tanh(flat @ p["W1"] + p["b1"])
    logits = h @ p["W2"] + p["b2"]
    e = np.exp(logits - logits.max(1, keepdims=True)); pr = e / e.sum(1, keepdims=True)
    loss = -np.log(pr[np.arange(N), Y]).mean()
    dl = pr.copy(); dl[np.arange(N), Y] -= 1; dl /= N
    dh = (dl @ p["W2"].T) * (1 - h * h)
    dC = np.zeros_like(p["C"]); np.add.at(dC, X, (dh @ p["W1"].T).reshape(N, ctx, -1))
    return loss, {"C": dC, "W1": flat.T @ dh, "b1": dh.sum(0), "W2": h.T @ dl, "b2": dl.sum(0)}


def data(V=9, ctx=3, n=25, seed=1):
    rng = np.random.default_rng(seed)
    X = rng.integers(0, V, (n, ctx)); X[1] = X[0]
    return X, rng.integers(0, V, n)


def test_autograd_not_hand_written_backward():
    """the port does not import your mlp_lm and calls autograd (backward / autograd.grad)"""
    kdtest.assert_no_imports("torch_port", {"mlp_lm"}, "autograd must do this work")
    assert {"backward", "grad"} & kdtest.used_names("torch_port")


def test_to_torch():
    """to_torch gives float64 leaf tensors that require grad and are copies of the numpy arrays"""
    p = ref_params()
    t = tp.to_torch(p)
    assert set(t) == set(p)
    for k, v in t.items():
        assert isinstance(v, torch.Tensor) and v.dtype == torch.float64 and v.requires_grad and v.is_leaf, k
        assert np.array_equal(v.detach().numpy(), p[k])
    t["C"].data.zero_()
    assert p["C"].any(), "to_torch must copy, not share memory with the numpy array"


def test_loss_matches_numpy():
    """loss_fn equals the numpy forward loss and is a scalar tensor that remembers its graph"""
    p = ref_params(); X, Y = data()
    t = tp.to_torch(p)
    loss = tp.loss_fn(t, torch.from_numpy(X), torch.from_numpy(Y))
    assert loss.dim() == 0 and loss.grad_fn is not None
    assert loss.item() == pytest.approx(ref_loss_and_grads(p, X, Y)[0], abs=1e-12)


def test_autograd_gradients_equal_the_hand_derived_ones():
    """torch_grads equals the hand-derived gradients for every parameter, and is the same when called twice"""
    p = ref_params(seed=3); X, Y = data(seed=4)
    t = tp.to_torch(p)
    Xt, Yt = torch.from_numpy(X), torch.from_numpy(Y)
    g1 = tp.torch_grads(t, Xt, Yt)
    g2 = tp.torch_grads(t, Xt, Yt)
    _, ref = ref_loss_and_grads(p, X, Y)
    assert set(g1) == set(ref)
    for k in ref:
        assert isinstance(g1[k], np.ndarray) and g1[k].dtype == np.float64 and g1[k].shape == ref[k].shape
        assert np.abs(g1[k] - ref[k]).max() < 1e-12, k
        assert np.array_equal(g1[k], g2[k]), "gradients accumulated across calls: clear them first"


def test_agrees_with_your_numpy_backward_from_lesson_14():
    """autograd and your own mlp_lm.backward agree (skipped if lesson 14 is not in the workspace)"""
    mlp_lm = pytest.importorskip("mlp_lm")
    p = ref_params(seed=5); X, Y = data(seed=6)
    loss, cache = mlp_lm.forward(p, X, Y)
    hand = mlp_lm.backward(p, cache)
    auto = tp.torch_grads(tp.to_torch(p), torch.from_numpy(X), torch.from_numpy(Y))
    assert tp.max_abs_diff(hand, auto) < 1e-10


def test_max_abs_diff():
    """max_abs_diff is the maximum over keys and entries"""
    a = {"x": np.array([1.0, 2.0]), "y": np.zeros((2, 2))}
    b = {"x": np.array([1.0, 2.5]), "y": np.array([[0, 0], [0, -3.0]])}
    assert tp.max_abs_diff(a, b) == 3.0 and tp.max_abs_diff(a, a) == 0.0


def test_sgd_step():
    """sgd_step updates in place under no_grad, keeps leaf tensors with requires_grad, and clears the gradients"""
    p = ref_params(seed=7); X, Y = data(seed=8)
    t = tp.to_torch(p)
    tp.torch_grads(t, torch.from_numpy(X), torch.from_numpy(Y))
    ids = {k: id(v) for k, v in t.items()}
    g = {k: v.grad.clone() for k, v in t.items()}
    before = {k: v.detach().clone() for k, v in t.items()}
    tp.sgd_step(t, 0.1)
    for k, v in t.items():
        assert id(v) == ids[k] and v.is_leaf and v.requires_grad and v.grad is None, k
        assert torch.allclose(v.detach(), before[k] - 0.1 * g[k]), k


def test_training_works_and_is_seeded():
    """train_torch lowers the loss on a repeating pattern, returns Python floats, and is deterministic per seed"""
    ids = np.tile([0, 1, 2, 3], 100)
    N = len(ids) - 2
    X = np.stack([ids[:N], ids[1:N + 1]], axis=1); Y = ids[2:]
    p = {"C": np.random.default_rng(0).normal(size=(4, 3)), "W1": np.random.default_rng(1).normal(size=(6, 10)) * 0.4,
         "b1": np.zeros(10), "W2": np.random.default_rng(2).normal(size=(10, 4)) * 0.1, "b2": np.zeros(4)}
    t1, l1 = tp.train_torch(p, X, Y, steps=300, lr=0.5, batch_size=32, seed=3)
    t2, l2 = tp.train_torch(p, X, Y, steps=300, lr=0.5, batch_size=32, seed=3)
    assert l1 == l2 and all(type(x) is float for x in l1) and len(l1) == 300
    assert np.mean(l1[-20:]) < 0.3 * np.mean(l1[:20])
    assert np.array_equal(t1["W1"].detach().numpy(), t2["W1"].detach().numpy())
    assert np.array_equal(p["C"], np.random.default_rng(0).normal(size=(4, 3))), "the numpy params must not be modified"
