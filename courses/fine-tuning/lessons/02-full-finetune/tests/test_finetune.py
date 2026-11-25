import math

import pytest
import torch

import finetune as ft
from kdlib import kdtest, refimpl as I, tasks as T


@pytest.fixture(scope="module")
def world():
    m, tok = I.ref_base()
    return m, tok, I.ids_of(tok, T.alice("train")), I.ids_of(tok, T.alice("val"))[:4000]


def test_no_fine_tuning_libraries():
    """plain PyTorch: no peft, trl, transformers, accelerate"""
    kdtest.assert_no_imports("finetune", {"peft", "trl", "transformers", "accelerate"})


def test_lr_schedule():
    """linear warm-up to lr, cosine decay to lr * min_ratio at the end, flat afterwards"""
    f = ft.lr_at
    assert f(0, 100, 1.0) == pytest.approx(1.0) and f(100, 100, 1.0) == pytest.approx(0.1) and f(500, 100, 1.0) == pytest.approx(0.1)
    assert f(50, 100, 1.0) == pytest.approx(0.55)
    assert [f(s, 100, 2.0, warmup=4) for s in range(4)] == pytest.approx([0.5, 1.0, 1.5, 2.0])
    assert f(4, 100, 2.0, warmup=4) == pytest.approx(2.0)
    assert f(52, 100, 2.0, warmup=4, min_ratio=0.0) == pytest.approx(1.0)
    vals = [f(s, 100, 1.0, warmup=10) for s in range(10, 101)]
    assert all(a >= b - 1e-12 for a, b in zip(vals, vals[1:])), "decay must not go up"


def test_get_batch():
    """get_batch gives shifted windows, repeats with the same generator seed, and rejects too-short data"""
    ids = torch.arange(100)
    x, y = ft.get_batch(ids, 8, 5, torch.Generator().manual_seed(1))
    assert x.shape == y.shape == (5, 8) and torch.equal(y, x + 1)
    x2, _ = ft.get_batch(ids, 8, 5, torch.Generator().manual_seed(1))
    x3, _ = ft.get_batch(ids, 8, 5, torch.Generator().manual_seed(2))
    assert torch.equal(x, x2) and not torch.equal(x, x3)
    with pytest.raises(ValueError):
        ft.get_batch(torch.arange(8), 8, 2, torch.Generator())


def test_finetune_updates_every_weight(world):
    """after a few steps every parameter tensor has changed, the loss list has one entry per step, and the mode is restored"""
    m, tok, tr, va = world
    mm = I.clone(m)
    before = {k: v.clone() for k, v in mm.state_dict().items()}
    mm.eval()
    losses = ft.finetune(mm, tr, steps=5, lr=1e-3, batch_size=4)
    assert len(losses) == 5 and all(isinstance(l, float) for l in losses)
    assert not mm.training
    same = [k for k, v in mm.state_dict().items() if torch.equal(v, before[k])]
    assert not same, "not updated: %s" % same[:3]


def test_same_seed_same_result(world):
    """the run is reproducible: same seed, same weights; another seed, other weights"""
    m, tok, tr, va = world
    outs = []
    for seed in (3, 3, 4):
        mm = I.clone(m)
        ft.finetune(mm, tr, steps=4, lr=1e-3, batch_size=4, seed=seed)
        outs.append(mm.lm_head.weight.detach().clone())
    assert torch.equal(outs[0], outs[1]) and not torch.equal(outs[0], outs[2])


def test_style_loss_drops(world):
    """150 steps at lr 5e-4 lower the loss on held-out text of the new style by well over 0.25 nats"""
    m, tok, tr, va = world
    mm = I.clone(m)
    before = I.text_loss(mm, va)
    losses = ft.finetune(mm, tr, steps=150, lr=5e-4, warmup=10)
    after = I.text_loss(mm, va)
    assert after < before - 0.25, "held-out style loss %.3f -> %.3f" % (before, after)
    assert sum(losses[-20:]) / 20 < sum(losses[:20]) / 20


def test_too_high_a_learning_rate_hurts(world):
    """the same budget at lr 1e-2 ends worse on held-out style text than at 5e-4"""
    m, tok, tr, va = world
    good, bad = I.clone(m), I.clone(m)
    ft.finetune(good, tr, steps=100, lr=5e-4, warmup=10)
    ft.finetune(bad, tr, steps=100, lr=1e-2, warmup=10)
    g, b = I.text_loss(good, va), I.text_loss(bad, va)
    assert g < b - 0.1, "lr 5e-4 gave %.3f and lr 1e-2 gave %.3f; the large rate should be clearly worse" % (g, b)
