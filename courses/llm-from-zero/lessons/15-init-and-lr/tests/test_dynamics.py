import math

import numpy as np
import pytest

import dynamics
import mlp_lm
from kdlib import kdtest
from kdlib.corpus import bundled_splits


def real_data(n=60000):
    tr, _, _ = bundled_splits()
    chars = sorted(set(tr)); stoi = {c: i for i, c in enumerate(chars)}
    ids = np.array([stoi[c] for c in tr[:n]])
    X, Y = mlp_lm.make_dataset(ids, 3)
    return len(chars), X, Y


def test_no_deep_learning_libraries():
    """numpy only: no torch, tensorflow, jax"""
    kdtest.assert_no_imports("dynamics", {"torch", "tensorflow", "jax", "sklearn", "scipy"})


def test_make_params_and_scales():
    """shapes, seeded draws and the requested standard deviations; kaiming_scale is gain / sqrt(fan_in)"""
    assert dynamics.kaiming_scale(100) == pytest.approx(5 / 3 / 10) and dynamics.kaiming_scale(25, gain=1.0) == pytest.approx(0.2)
    p = dynamics.make_params(50, 4, 16, 200, seed=1)
    assert [p[k].shape for k in ("C", "W1", "b1", "W2", "b2")] == [(50, 16), (64, 200), (200,), (200, 50), (50,)]
    assert p["W1"].std() == pytest.approx(dynamics.kaiming_scale(64), rel=0.1) and p["W2"].std() == pytest.approx(0.01, rel=0.1)
    assert p["C"].std() == pytest.approx(1.0, rel=0.1) and not p["b1"].any() and not p["b2"].any()
    q = dynamics.make_params(50, 4, 16, 200, seed=1)
    assert all(np.array_equal(p[k], q[k]) for k in p)
    r = dynamics.make_params(50, 4, 16, 200, seed=1, w1_scale=0.5, w2_scale=2.0)
    assert r["W1"].std() == pytest.approx(0.5, rel=0.1) and r["W2"].std() == pytest.approx(2.0, rel=0.1)
    assert np.array_equal(r["C"], p["C"]), "C is drawn first, so it does not depend on the scales"


def test_first_loss_is_ln_v_only_with_a_small_output_layer():
    """with a small W2 the first loss is about ln V; a large W2 gives a much larger first loss (the hockey stick)"""
    V, X, Y = real_data()
    good = mlp_lm.forward(dynamics.make_params(V, 3, 8, 64), X[:3000], Y[:3000])[0]
    bad = mlp_lm.forward(dynamics.make_params(V, 3, 8, 64, w2_scale=1.0), X[:3000], Y[:3000])[0]
    assert abs(good - math.log(V)) < 0.15, (good, math.log(V))
    assert bad > good + 1.0


def test_hidden_stats_show_saturation():
    """tiny W1 gives near-zero activations, huge W1 saturates tanh, Kaiming scaling sits in between"""
    V, X, Y = real_data()
    def stats(**kw):
        return dynamics.hidden_stats(dynamics.make_params(V, 3, 8, 64, **kw), X[:3000])
    small, big, mid = stats(w1_scale=0.01), stats(w1_scale=3.0), stats()
    assert set(mid) == {"mean", "std", "saturated"}
    assert small["std"] < 0.1 and small["saturated"] == 0.0
    assert big["saturated"] > 0.5 and big["std"] > 0.8
    assert 0.3 < mid["std"] < 0.95 and mid["saturated"] < 0.2
    raw = dynamics.hidden_stats({"C": np.ones((3, 2)), "W1": np.ones((4, 1)) * 10, "b1": np.zeros(1), "W2": None, "b2": None},
                                np.zeros((5, 2), dtype=np.int64))
    assert raw["saturated"] == 1.0 and raw["mean"] > 0.99


def test_update_ratio():
    """update_ratio covers the matrix parameters and equals log10(lr * std(grad) / std(param))"""
    p = dynamics.make_params(10, 2, 4, 8, seed=0)
    X, Y = np.random.default_rng(0).integers(0, 10, (30, 2)), np.random.default_rng(1).integers(0, 10, 30)
    loss, cache = mlp_lm.forward(p, X, Y)
    g = mlp_lm.backward(p, cache)
    r = dynamics.update_ratio(p, g, 0.1)
    assert set(r) == {"C", "W1", "W2"}
    assert r["W1"] == pytest.approx(math.log10(0.1 * g["W1"].std() / p["W1"].std()))


def test_lr_range_test():
    """the range test leaves params alone, grows lr geometrically from lo, records the loss before each update, and stops on divergence"""
    V, X, Y = real_data(30000)
    p = dynamics.make_params(V, 3, 8, 64)
    snap = {k: v.copy() for k, v in p.items()}
    rows = dynamics.lr_range_test(p, X, Y, lo=1e-3, hi=1.0, steps=30, batch_size=64, seed=2)
    assert all(np.array_equal(p[k], snap[k]) for k in p), "the caller's params must stay untouched"
    assert len(rows) == 30 and rows[0][0] == pytest.approx(1e-3) and rows[-1][0] == pytest.approx(1.0)
    ratios = [b[0] / a[0] for a, b in zip(rows, rows[1:])]
    assert max(ratios) / min(ratios) < 1.0001 and ratios[0] > 1
    idx = np.random.default_rng(2).integers(0, X.shape[0], 64)
    assert rows[0][1] == pytest.approx(mlp_lm.forward(p, X[idx], Y[idx])[0]), "first loss is measured before any update"
    assert rows == dynamics.lr_range_test(p, X, Y, lo=1e-3, hi=1.0, steps=30, batch_size=64, seed=2)
    hot = dynamics.lr_range_test(p, X, Y, lo=1e-2, hi=1e5, steps=80, batch_size=64, seed=2)
    assert len(hot) < 80 and not (np.isfinite(hot[-1][1]) and hot[-1][1] <= 4 * hot[0][1]), "must stop once the loss blows up"


def test_suggest_lr():
    """suggest_lr is the lr of the lowest finite loss divided by 10"""
    rows = [(0.001, 4.0), (0.01, 3.0), (0.1, 2.0), (1.0, float("nan")), (10.0, float("inf"))]
    assert dynamics.suggest_lr(rows) == pytest.approx(0.01)
    assert dynamics.suggest_lr([(0.1, 3.0), (1.0, 2.5), (3.0, 9.0)]) == pytest.approx(0.1)


def test_the_suggested_rate_trains_better_than_bad_ones():
    """training with the suggested rate beats a rate 1000 times smaller and one 100 times larger"""
    V, X, Y = real_data(80000)
    p0 = dynamics.make_params(V, 3, 8, 64, seed=0)
    lr = dynamics.suggest_lr(dynamics.lr_range_test(p0, X, Y, lo=1e-3, hi=10.0, steps=60, batch_size=64, seed=0))
    final = {}
    for name, rate in (("good", lr), ("tiny", lr / 1000), ("huge", lr * 100)):
        p = dynamics.make_params(V, 3, 8, 64, seed=0)
        mlp_lm.train(p, X, Y, steps=500, lr=rate, batch_size=64, seed=1)
        final[name] = mlp_lm.evaluate_loss(p, X[:5000], Y[:5000])
    assert final["good"] < final["tiny"] - 0.2, final
    assert final["good"] < final["huge"] - 0.2 or not np.isfinite(final["huge"]), final
    assert final["good"] < 2.7, final
