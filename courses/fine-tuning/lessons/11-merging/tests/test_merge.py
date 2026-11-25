import os

import pytest
import torch
import torch.nn as nn

import finetune
import lora as L
import merge as M
from kdlib import kdtest, refimpl as I, refmodel as R, tasks as T

CK = "/kdlib/kdlib/data/ref_base.pt"


@pytest.fixture(scope="module")
def world():
    m, tok = I.ref_base()
    return m, tok, I.ids_of(tok, T.alice("train")), I.ids_of(tok, T.alice("val"))[:3000]


def adapted(m, r=8, alpha=4.0, seed=0):
    """a GPT with adapters whose B matrices are random (as after real training), scale alpha/r != 1"""
    mm = I.clone(m)
    L.add_lora(mm, targets=("key", "query", "value", "proj", "fc1", "fc2"), r=r, alpha=alpha)
    g = torch.Generator().manual_seed(seed)
    with torch.no_grad():
        for n, p in mm.named_parameters():
            if n.endswith("lora_B"):
                p.copy_(torch.randn(p.shape, generator=g) * 0.05)
    return mm


def test_no_libraries():
    """hand-written merge: no peft, trl, transformers"""
    kdtest.assert_no_imports("merge", {"peft", "trl", "transformers", "accelerate"})


def test_merged_weight_formula():
    """merged_weight is W + (alpha/r) B A as a new tensor; the layer is untouched"""
    torch.manual_seed(0)
    lin = L.LoRALinear(nn.Linear(10, 6), r=4, alpha=2)
    with torch.no_grad():
        lin.lora_B.normal_()
    w0, a0, b0 = lin.base.weight.clone(), lin.lora_A.clone(), lin.lora_B.clone()
    w = M.merged_weight(lin)
    assert w.shape == (6, 10) and torch.allclose(w, w0 + 0.5 * b0 @ a0, atol=1e-6)
    assert torch.equal(lin.base.weight, w0) and torch.equal(lin.lora_A, a0) and torch.equal(lin.lora_B, b0)
    x = torch.randn(3, 10)
    assert torch.allclose(x @ w.T + lin.base.bias, lin(x), atol=1e-5)


def test_merge_gives_the_same_outputs(world):
    """after merge_lora the logits equal the adapter model's (max difference below 1e-4) on several batches"""
    m = world[0]
    mm = adapted(m)
    xs = [torch.randint(0, 400, (3, 33), generator=torch.Generator().manual_seed(s)) for s in range(3)]
    with torch.no_grad():
        before = [mm(x)[0].clone() for x in xs]
    assert not torch.allclose(before[0], m(xs[0])[0], atol=1e-3), "the random adapters should change the output"
    n = M.merge_lora(mm)
    Lyr, H = 3, 4
    assert n == Lyr * (3 * H + 1 + 2)
    with torch.no_grad():
        for x, b in zip(xs, before):
            assert torch.allclose(mm(x)[0], b, atol=1e-4), "merged model differs: %.2e" % float((mm(x)[0] - b).abs().max())


def test_merged_model_is_a_plain_gpt(world):
    """no adapter modules remain; parameter names, shapes and the total count are those of the original GPT; embeddings unchanged; merging again does nothing"""
    m = world[0]
    mm = adapted(m)
    M.merge_lora(mm)
    assert not any(isinstance(x, L.LoRALinear) for x in mm.modules())
    sd, ref = mm.state_dict(), m.state_dict()
    assert list(sd) == list(ref) and all(sd[k].shape == ref[k].shape for k in ref)
    assert sum(p.numel() for p in mm.parameters()) == m.num_params() == 384864
    assert torch.equal(sd["tok_emb.weight"], ref["tok_emb.weight"]) and torch.equal(sd["blocks.1.ln1.weight"], ref["blocks.1.ln1.weight"])
    assert not torch.equal(sd["blocks.0.ffn.fc1.weight"], ref["blocks.0.ffn.fc1.weight"])
    assert torch.equal(sd["blocks.0.ffn.fc1.bias"], ref["blocks.0.ffn.fc1.bias"])
    fresh = R.GPT(**{"vocab_size": 457, "block_size": 64, "n_layer": 3, "n_head": 4, "n_embd": 96})
    fresh.load_state_dict(sd)                            # strict: loads into a plain GPT
    assert M.merge_lora(mm) == 0
    assert all(p.requires_grad for p in mm.parameters())


def test_merged_copy_keeps_the_original(world):
    """merged_copy leaves the adapter model (and its outputs) as they were, and max_logit_difference measures the gap"""
    m = world[0]
    mm = adapted(m)
    x = torch.randint(0, 400, (2, 40))
    with torch.no_grad():
        before = mm(x)[0].clone()
    c = M.merged_copy(mm)
    assert any(isinstance(z, L.LoRALinear) for z in mm.modules()) and not any(isinstance(z, L.LoRALinear) for z in c.modules())
    with torch.no_grad():
        assert torch.equal(mm(x)[0], before)
    assert M.max_logit_difference(mm, c, x) < 1e-4
    assert M.max_logit_difference(m, mm, x) > 1e-3
    mm.train(); c.eval()
    M.max_logit_difference(mm, c, x)
    assert mm.training and not c.training


def test_merged_checkpoint_round_trip(world, tmp_path):
    """save_merged_checkpoint writes a normal checkpoint (same keys as the base one, plus merged_from) that reproduces the outputs and is as large as the model"""
    m = world[0]
    mm = adapted(m)
    p = str(tmp_path / "out" / "merged.pt")
    size = M.save_merged_checkpoint(mm, CK, p, note="test r=8")
    assert size == os.path.getsize(p) and size > 0.9 * os.path.getsize(CK)
    ck = torch.load(p, weights_only=False)
    base_ck = torch.load(CK, weights_only=False)
    assert set(ck) == set(base_ck) | {"merged_from"} and ck["merged_from"] == "test r=8" and ck["gpt_config"] == base_ck["gpt_config"]
    loaded, tok = I.load_ckpt(p)
    x = torch.randint(0, 400, (2, 30))
    assert M.max_logit_difference(loaded, mm, x) < 1e-4
    assert any(isinstance(z, L.LoRALinear) for z in mm.modules()), "the model passed in must not be modified"
    ok = M.save_merged_checkpoint(M.merged_copy(mm), CK, str(tmp_path / "again.pt"))
    assert abs(ok - size) < 200


def test_trained_adapter_merges_without_losing_the_gain(world):
    """train a real adapter with your finetune: the merged model has the same held-out style loss (within 1e-3) and it is at least 0.2 better than the base"""
    m, tok, tr, va = world
    mm = I.clone(m)
    L.add_lora(mm, r=8, alpha=16)
    finetune.finetune(mm, tr, steps=80, lr=3e-3, warmup=10)
    c = M.merged_copy(mm)
    a, b, base_loss = I.text_loss(mm, va), I.text_loss(c, va), I.text_loss(m, va)
    assert abs(a - b) < 1e-3, "adapter %.4f vs merged %.4f" % (a, b)
    assert b < base_loss - 0.2
