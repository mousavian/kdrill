import math
import os

import pytest
import torch
import torch.nn as nn

import finetune
import lora as L
from kdlib import kdtest, refimpl as I, refmodel as R, tasks as T


@pytest.fixture(scope="module")
def world():
    m, tok = I.ref_base()
    return m, tok, I.ids_of(tok, T.alice("train")), I.ids_of(tok, T.alice("val"))[:4000], I.ids_of(tok, T.holmes("val"))[:4000]


def test_no_libraries():
    """hand-written LoRA: no peft, trl, transformers, parametrize"""
    kdtest.assert_no_imports("lora", {"peft", "trl", "transformers", "accelerate", "bitsandbytes"})
    kdtest.assert_not_used("lora", {"parametrize", "register_parametrization"})


def test_lora_linear_starts_as_the_base_layer():
    """at initialisation B is zero, so the wrapped layer gives exactly the base output; A is random; the base is shared and frozen"""
    torch.manual_seed(0)
    base = nn.Linear(12, 7)
    lin = L.LoRALinear(base, r=4, alpha=8)
    x = torch.randn(3, 5, 12)
    assert torch.equal(lin(x), base(x))
    assert lin.base is base and not any(p.requires_grad for p in base.parameters())
    assert lin.lora_A.shape == (4, 12) and lin.lora_B.shape == (7, 4) and lin.lora_A.requires_grad and lin.lora_B.requires_grad
    assert float(lin.lora_B.abs().sum()) == 0.0 and float(lin.lora_A.abs().sum()) > 0
    assert lin.scale == 2.0 and lin.r == 4 and lin.alpha == 8
    bound = 1 / math.sqrt(12)
    assert float(lin.lora_A.abs().max()) <= bound + 1e-6, "A should be initialised like nn.Linear (kaiming uniform, a=sqrt(5))"


def test_lora_linear_formula():
    """with B set, y = base(x) + alpha/r * x A^T B^T (the bias of the base is used once)"""
    torch.manual_seed(1)
    base = nn.Linear(10, 6)
    for r, alpha in ((4, 8), (4, 4), (2, 3)):
        lin = L.LoRALinear(base, r=r, alpha=alpha)
        with torch.no_grad():
            lin.lora_B.normal_()
        x = torch.randn(2, 3, 10)
        want = x @ base.weight.T + base.bias + (alpha / r) * (x @ lin.lora_A.T) @ lin.lora_B.T
        assert torch.allclose(lin(x), want, atol=1e-5), "r=%d alpha=%s" % (r, alpha)


def test_gradients_only_reach_the_adapter():
    """backward: the base weight gets no gradient; at the start B has a gradient and A none (B is zero, so A cannot matter yet)"""
    torch.manual_seed(2)
    base = nn.Linear(10, 6)
    lin = L.LoRALinear(base, r=3, alpha=6)
    lin(torch.randn(4, 10)).pow(2).sum().backward()
    assert base.weight.grad is None and base.bias.grad is None
    assert float(lin.lora_B.grad.abs().sum()) > 0 and float(lin.lora_A.grad.abs().sum()) == 0.0


def test_add_lora_to_the_gpt(world):
    """attention layers are wrapped (names returned), logits are unchanged at the start, everything else is frozen, the count follows the formula"""
    m, tok, *_ = world
    mm = I.clone(m)
    x = torch.randint(0, 400, (2, 20))
    with torch.no_grad():
        before = mm(x)[0]
    names = L.add_lora(mm, r=8, alpha=16)
    Lyr, H, C = len(mm.blocks), len(mm.blocks[0].attn.heads), mm.tok_emb.weight.shape[1]
    hs = C // H
    assert len(names) == len(set(names)) == Lyr * (3 * H + 1)
    assert "blocks.0.attn.heads.0.key" in names and "blocks.%d.attn.proj" % (Lyr - 1) in names and not any("ffn" in n for n in names)
    with torch.no_grad():
        assert torch.equal(mm(x)[0], before)
    want = Lyr * (3 * H * 8 * (C + hs) + 8 * (C + C))
    assert L.trainable_count(mm) == want, "trainable %d, formula %d" % (L.trainable_count(mm), want)
    for n, p in mm.named_parameters():
        assert p.requires_grad == (n.endswith("lora_A") or n.endswith("lora_B")), n
    assert len(L.lora_parameters(mm)) == 2 * len(names)


def test_add_lora_errors_and_target_choice(world):
    """other targets work (query and value only); a typo or a second call on the same layers raises ValueError"""
    m = world[0]
    mm = I.clone(m)
    names = L.add_lora(mm, targets=("query", "value"), r=4, alpha=4)
    assert len(names) == 2 * len(mm.blocks) * len(mm.blocks[0].attn.heads)
    with pytest.raises(ValueError):
        L.add_lora(mm, targets=("query", "value"), r=4, alpha=4)
    with pytest.raises(ValueError):
        L.add_lora(I.clone(m), targets=("querry",))


def test_training_moves_only_the_adapter_and_learns_the_style(world):
    """with your finetune(): 150 steps at lr 3e-3 change only A and B (every base tensor identical) and lower the held-out style loss by at least 0.2"""
    m, tok, tr, va, ov = world
    mm = I.clone(m)
    L.add_lora(mm, r=8, alpha=16)
    snap = {k: v.clone() for k, v in mm.state_dict().items() if "lora" not in k}
    b = I.text_loss(mm, va)
    finetune.finetune(mm, tr, steps=150, lr=3e-3, warmup=10)
    for k, v in mm.state_dict().items():
        if "lora" not in k:
            assert torch.equal(v, snap[k]), "base tensor %s changed" % k
    assert any(float(p.abs().sum()) > 0 for n, p in L.lora_parameters(mm) if n.endswith("lora_B"))
    a = I.text_loss(mm, va)
    assert a < b - 0.2, "style loss %.3f -> %.3f" % (b, a)


def test_adapter_file(world, tmp_path):
    """save_adapter stores only A and B (small file, size returned); load_adapter restores them in a fresh model; another rank is refused"""
    m, tok, tr, va, ov = world
    a = I.clone(m)
    L.add_lora(a, r=8, alpha=16)
    finetune.finetune(a, tr, steps=5, lr=3e-3)
    p = str(tmp_path / "x" / "ad.pt")
    size = L.save_adapter(a, p)
    assert size == os.path.getsize(p)
    n = L.trainable_count(a)
    assert 4 * n <= size <= 4 * n + 30000, "file of %d bytes for %d parameters" % (size, n)
    assert size < os.path.getsize("/kdlib/kdlib/data/ref_base.pt") * 0.25
    b = I.clone(m)
    L.add_lora(b, r=8, alpha=16, seed=123)
    x = torch.randint(0, 400, (2, 24))
    with torch.no_grad():
        assert not torch.allclose(a(x)[0], b(x)[0])
        L.load_adapter(b, p)
        assert torch.equal(a(x)[0], b(x)[0])
    c = I.clone(m)
    L.add_lora(c, r=4, alpha=8)
    with pytest.raises(ValueError):
        L.load_adapter(c, p)
