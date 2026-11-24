import math
import os

import numpy as np
import pytest
import torch

import scaling as S
from kdlib.corpus import bundled_splits


def test_flops_and_steps():
    """training FLOPs are 6 N D; a budget becomes round(budget / (6 N B T)) steps, at least 1"""
    assert S.train_flops(1_000_000, 2_000_000) == 6 * 1e6 * 2e6 and isinstance(S.train_flops(10, 10), float)
    assert S.steps_for_budget(6e12, 1e6, 32, 100) == round(6e12 / (6 * 1e6 * 32 * 100))
    assert S.steps_for_budget(1.0, 1e9, 32, 100) == 1
    a = S.steps_for_budget(1e12, 1e5, 16, 32); b = S.steps_for_budget(1e12, 4e5, 16, 32)
    assert a == pytest.approx(4 * b, rel=0.01), "four times the parameters get a quarter of the steps"


def test_power_law_fit():
    """fit_power_law recovers a and b from exact and from noisy data and predict_power_law inverts it"""
    xs = np.array([1e5, 3e5, 1e6, 3e6, 1e7])
    a, b = S.fit_power_law(xs, 7.5 * xs ** -0.3)
    assert a == pytest.approx(7.5, rel=1e-6) and b == pytest.approx(-0.3, abs=1e-9)
    noise = np.exp(np.random.default_rng(0).normal(0, 0.01, 5))
    a2, b2 = S.fit_power_law(xs, 7.5 * xs ** -0.3 * noise)
    assert b2 == pytest.approx(-0.3, abs=0.02) and a2 == pytest.approx(7.5, rel=0.2)
    assert S.predict_power_law(a, b, 1e8) == pytest.approx(7.5 * 1e8 ** -0.3)
    for bad in ([1.0], [], ):
        with pytest.raises(ValueError):
            S.fit_power_law(bad, bad)
    with pytest.raises(ValueError):
        S.fit_power_law([1, 2, 3], [1, 0, 2])
    with pytest.raises(ValueError):
        S.fit_power_law([1, -2, 3], [1, 2, 2])


def test_plot_is_a_real_png(tmp_path):
    """plot_curves writes a valid PNG (creating directories), and a different plot for different data"""
    p1 = S.plot_curves({"a": [(1e3, 3.0), (1e4, 2.5), (1e5, 2.2)], "b": [(1e3, 3.2), (1e5, 2.0)]}, str(tmp_path / "x" / "y" / "a.png"), title="t")
    p2 = S.plot_curves({"a": [(1e3, 1.0), (1e4, 1.5)]}, str(tmp_path / "b.png"))
    assert p1.endswith("a.png") and os.path.exists(p1)
    d1, d2 = open(p1, "rb").read(), open(p2, "rb").read()
    assert d1[:8] == b"\x89PNG\r\n\x1a\n" and len(d1) > 3000 and d1 != d2


def test_run_one_spends_the_budget():
    """run_one trains for the number of steps the budget allows and reports consistent numbers; bigger models get fewer steps"""
    tr, va, _ = bundled_splits()
    chars = sorted(set(tr)); stoi = {c: i for i, c in enumerate(chars)}
    enc = lambda s: torch.tensor([stoi.get(c, 0) for c in s], dtype=torch.long)
    ti, vi = enc(tr[:60000]), enc(va[:20000])
    small = S.run_one(dict(n_layer=1, n_head=2, n_embd=24), 3e9, ti, vi, len(chars), block_size=16, batch_size=8, seed=0)
    big = S.run_one(dict(n_layer=2, n_head=2, n_embd=48), 3e9, ti, vi, len(chars), block_size=16, batch_size=8, seed=0)
    for r in (small, big):
        assert set(r) == {"n_params", "steps", "tokens", "flops", "train_loss", "val_loss"}
        assert r["tokens"] == r["steps"] * 8 * 16 and r["flops"] == pytest.approx(6 * r["n_params"] * r["tokens"])
        assert r["flops"] == pytest.approx(3e9, rel=0.1)
        assert math.isfinite(r["val_loss"]) and r["val_loss"] < math.log(len(chars)) - 0.3, r
    assert big["n_params"] > small["n_params"] and big["steps"] < small["steps"]
    again = S.run_one(dict(n_layer=1, n_head=2, n_embd=24), 3e9, ti, vi, len(chars), block_size=16, batch_size=8, seed=0)
    assert again == small, "same seed, same result"
