import pytest
import torch

import lora as L
import sweep as S
from kdlib import kdtest, refimpl as I, tasks as T


@pytest.fixture(scope="module")
def world():
    m, tok = I.ref_base()
    return m, tok, I.ids_of(tok, T.alice("train")), I.ids_of(tok, T.alice("val"))[:3000]


def res(r, trainable, loss, alpha=None):
    return {"r": r, "alpha": alpha or 2 * r, "scale": 2.0, "trainable": trainable, "val_loss": loss}


def test_no_libraries():
    """hand-written experiments: no peft, trl, transformers"""
    kdtest.assert_no_imports("sweep", {"peft", "trl", "transformers", "accelerate"})


def test_smallest_rank_rule():
    """smallest_rank picks the cheapest result that reaches the required share of the full fine-tuning gain, or None"""
    rs = [res(1, 100, 3.31), res(2, 200, 3.20), res(4, 400, 3.12), res(8, 800, 3.09), res(16, 1600, 3.08)]
    # base 3.5, full 3.0 -> gain 0.5; 80% needs a loss of at most 3.1
    assert S.smallest_rank(rs, 3.5, 3.0, 0.8)["r"] == 8
    assert S.smallest_rank(rs, 3.5, 3.0, 0.4)["r"] == 2
    assert S.smallest_rank(rs, 3.5, 3.0, 1.0) is None
    assert S.smallest_rank(rs, 3.5, 3.0, 0.1)["r"] == 1
    shuffled = [rs[3], rs[0], rs[4], rs[2], rs[1]]
    assert S.smallest_rank(shuffled, 3.5, 3.0, 0.8)["r"] == 8, "order of the results must not matter"
    tie = [res(4, 500, 3.0), res(2, 500, 3.0)]
    assert S.smallest_rank(tie, 3.5, 3.0, 0.8)["r"] == 2, "ties go to the smaller rank"


def test_lora_run_reports_and_leaves_the_base_alone(world):
    """lora_run returns r, alpha, scale, the trainable count from the formula and a validation loss, and does not touch the base model"""
    m, tok, tr, va = world
    snap = {k: v.clone() for k, v in m.state_dict().items()}
    out = S.lora_run(m, tr, va, r=4, alpha=8, steps=5)
    assert set(out) >= {"r", "alpha", "scale", "trainable", "val_loss"} and out["scale"] == 2.0 and out["r"] == 4 and out["alpha"] == 8
    C, H, Lyr = 96, 4, 3
    assert out["trainable"] == Lyr * (3 * H * 4 * (C + C // H) + 4 * 2 * C)
    assert out["val_loss"] == pytest.approx(I.text_loss(I.clone(m), va), abs=1.0)
    assert all(torch.equal(v, snap[k]) for k, v in m.state_dict().items()), "the base model was modified"
    assert not any(isinstance(x, L.LoRALinear) for x in m.modules()), "adapters were added to the base itself"


def test_runs_are_reproducible_and_independent(world):
    """the same configuration gives the same loss, and the result does not depend on what ran before it"""
    m, tok, tr, va = world
    a = S.lora_run(m, tr, va, 2, 4, steps=6)["val_loss"]
    out = S.run_sweep(m, tr, va, [(4, 8), (2, 4)], steps=6)
    assert [o["r"] for o in out] == [4, 2] and out[1]["val_loss"] == pytest.approx(a, abs=1e-6)


def test_more_rank_and_more_scale_learn_more(world):
    """80 steps at lr 3e-3: rank 8 beats rank 1 by at least 0.08, and alpha 16 beats alpha 1 (same rank) by at least 0.06"""
    m, tok, tr, va = world
    out = S.run_sweep(m, tr, va, [(1, 2), (8, 16), (8, 1)], steps=80)
    r1, r8, a1 = (o["val_loss"] for o in out)
    assert r8 < r1 - 0.08, "rank 1: %.3f, rank 8: %.3f" % (r1, r8)
    assert r8 < a1 - 0.06, "alpha 1: %.3f, alpha 16: %.3f" % (a1, r8)
    assert out[1]["trainable"] == 8 * out[0]["trainable"]
