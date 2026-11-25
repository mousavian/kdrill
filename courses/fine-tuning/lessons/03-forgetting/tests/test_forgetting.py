import pytest
import torch

import finetune
import forgetting as fg
from kdlib import kdtest, refimpl as I, tasks as T


@pytest.fixture(scope="module")
def world():
    m, tok = I.ref_base()
    return (m, tok, I.ids_of(tok, T.alice("train")), I.ids_of(tok, T.holmes("train")),
            I.ids_of(tok, T.alice("val"))[:4000], I.ids_of(tok, T.holmes("val"))[:4000])


def test_forgetting_number():
    """forgetting is the relative increase of the original-text loss"""
    assert fg.forgetting(2.0, 2.5) == pytest.approx(0.25)
    assert fg.forgetting(3.0, 3.0) == 0.0
    assert fg.forgetting(2.0, 1.9) == pytest.approx(-0.05)


def test_mixed_batch_composition():
    """replay=0.25 of 8 rows: six windows of the new text first, then two of the old text; shifted targets"""
    new, old = torch.arange(1000, 1400), torch.arange(0, 400)
    g = torch.Generator().manual_seed(0)
    x, y = fg.mixed_batch(new, old, 8, 10, 0.25, g)
    assert x.shape == y.shape == (8, 10) and torch.equal(y, x + 1)
    assert bool((x[:6] >= 1000).all()) and bool((x[6:] < 400).all()), "new rows come first, old rows last"
    x, _ = fg.mixed_batch(new, old, 8, 10, 1.0, g)
    assert bool((x < 400).all())
    x, _ = fg.mixed_batch(new, old, 3, 10, 0.5, g)       # round(1.5) = 2 old rows (Python rounds half to even)
    assert int((x[:, 0] < 400).sum()) == 2


def test_mixed_batch_stream_and_errors():
    """replay=0 consumes the generator exactly like get_batch; replay outside [0, 1] is an error"""
    new, old = torch.arange(1000, 1400), torch.arange(0, 400)
    a = fg.mixed_batch(new, old, 6, 10, 0.0, torch.Generator().manual_seed(7))
    b = finetune.get_batch(new, 10, 6, torch.Generator().manual_seed(7))
    assert torch.equal(a[0], b[0]) and torch.equal(a[1], b[1])
    for bad in (-0.1, 1.5):
        with pytest.raises(ValueError):
            fg.mixed_batch(new, old, 6, 10, bad, torch.Generator())


def test_replay_zero_is_plain_finetuning(world):
    """finetune_mixed with replay=0 ends with exactly the weights of finetune()"""
    m, tok, new, old, sv, ov = world
    a, b = I.clone(m), I.clone(m)
    fg.finetune_mixed(a, new, old, steps=6, lr=1e-3, replay=0.0, batch_size=4, seed=2, warmup=2)
    finetune.finetune(b, new, steps=6, lr=1e-3, batch_size=4, seed=2, warmup=2)
    assert all(torch.allclose(p, q, atol=1e-6) for p, q in zip(a.parameters(), b.parameters())), "differs from finetune() (optimizer settings, schedule or batches)"


def test_no_libraries():
    """plain PyTorch"""
    kdtest.assert_no_imports("forgetting", {"peft", "trl", "transformers", "accelerate"})


def test_replay_reduces_forgetting(world):
    """lr 1e-3, 150 steps: replaying half old text keeps the original loss at least 0.15 lower than no replay, and still learns the style"""
    m, tok, new, old, sv, ov = world
    base_style = I.text_loss(m, sv)
    plain, mixed = I.clone(m), I.clone(m)
    fg.finetune_mixed(plain, new, old, steps=150, lr=1e-3, replay=0.0)
    fg.finetune_mixed(mixed, new, old, steps=150, lr=1e-3, replay=0.5)
    o_plain, o_mixed = I.text_loss(plain, ov), I.text_loss(mixed, ov)
    assert o_mixed < o_plain - 0.15, "original loss %.3f without replay, %.3f with replay" % (o_plain, o_mixed)
    s_mixed = I.text_loss(mixed, sv)
    assert s_mixed < base_style - 0.2, "style loss only %.3f -> %.3f with replay" % (base_style, s_mixed)
