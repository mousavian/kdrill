import math

import pytest
import torch
import torch.nn as nn

import gpt as G
from kdlib import kdtest


def make(V=65, T=16, L=2, H=2, C=32, dropout=0.0, seed=0):
    torch.manual_seed(seed)
    return G.GPT(V, T, L, H, C, dropout)


def test_no_library_transformer():
    """no nn.Transformer*, MultiheadAttention or scaled_dot_product_attention anywhere in gpt.py"""
    kdtest.assert_not_used("gpt", {"MultiheadAttention", "scaled_dot_product_attention", "TransformerDecoder", "TransformerDecoderLayer",
                                    "TransformerEncoder", "TransformerEncoderLayer", "Transformer"})


def test_structure_and_weight_tying():
    """the named parts exist, the output layer shares its weight with the token embedding (one Parameter object)"""
    m = make()
    assert isinstance(m.tok_emb, nn.Embedding) and m.tok_emb.weight.shape == (65, 32)
    assert isinstance(m.pos_emb, nn.Embedding) and m.pos_emb.weight.shape == (16, 32)
    assert len(m.blocks) == 2 and isinstance(m.ln_f, nn.LayerNorm) and isinstance(m.drop, nn.Dropout)
    assert isinstance(m.lm_head, nn.Linear) and m.lm_head.bias is None
    assert m.lm_head.weight is m.tok_emb.weight, "tie the weights: lm_head.weight = tok_emb.weight"


def test_forward_shapes_and_errors():
    """logits are (B, T, V), loss is None without targets; a sequence longer than block_size raises ValueError"""
    m = make().eval()
    x = torch.randint(0, 65, (3, 10))
    logits, loss = m(x)
    assert logits.shape == (3, 10, 65) and loss is None
    logits, loss = m(x, x)
    assert loss.dim() == 0 and loss.item() > 0
    assert m(torch.randint(0, 65, (2, 1)))[0].shape == (2, 1, 65)
    with pytest.raises(ValueError):
        m(torch.randint(0, 65, (1, 17)))


def test_initial_loss_is_ln_v():
    """a freshly initialised GPT predicts almost uniformly: the first loss is close to ln V"""
    m = make(V=65, seed=1)
    x = torch.randint(0, 65, (16, 16))
    loss = m(x, torch.randint(0, 65, (16, 16)))[1].item()
    assert abs(loss - math.log(65)) < 0.12, "initial loss %.3f, ln V = %.3f" % (loss, math.log(65))


def test_initialisation_scales():
    """weights ~ N(0, 0.02), residual projections ~ N(0, 0.02/sqrt(2 n_layer)), biases zero, LayerNorm untouched"""
    m = make(V=200, T=32, L=4, H=4, C=128, seed=2)
    assert m.tok_emb.weight.std().item() == pytest.approx(0.02, rel=0.1) and m.pos_emb.weight.std().item() == pytest.approx(0.02, rel=0.15)
    blk = m.blocks[0]
    assert blk.ffn.fc1.weight.std().item() == pytest.approx(0.02, rel=0.1)
    assert blk.attn.heads[0].key.weight.std().item() == pytest.approx(0.02, rel=0.15)
    want = 0.02 / math.sqrt(2 * 4)
    assert blk.attn.proj.weight.std().item() == pytest.approx(want, rel=0.1) and blk.ffn.fc2.weight.std().item() == pytest.approx(want, rel=0.1)
    assert not blk.ffn.fc1.bias.any() and not blk.attn.proj.bias.any()
    assert torch.equal(m.ln_f.weight, torch.ones(128)) and not m.ln_f.bias.any()


def test_parameter_count_formula():
    """gpt_param_count equals the real number (tied weights counted once) and num_params agrees"""
    for V, T, L, H, C in [(65, 16, 2, 2, 32), (100, 8, 3, 4, 48), (30, 64, 1, 1, 16)]:
        m = make(V, T, L, H, C)
        real = sum(p.numel() for p in m.parameters())
        assert G.gpt_param_count(V, T, L, C) == real == m.num_params(), (V, T, L, C, G.gpt_param_count(V, T, L, C), real)
        assert m.num_params(non_embedding=True) == real - T * C
    assert G.gpt_param_count(50257, 1024, 12, 768) == 124_412_160, "GPT-2 small shape, with bias-free query/key/value maps"


def test_whole_model_is_causal():
    """changing tokens after position t never changes the logits at positions <= t"""
    m = make(T=12).eval()
    x = torch.randint(0, 65, (2, 12))
    y = x.clone(); y[:, 7:] = torch.randint(0, 65, (2, 5))
    assert torch.allclose(m(y)[0][:, :7], m(x)[0][:, :7], atol=1e-5)
    assert not torch.allclose(m(y)[0][:, 9], m(x)[0][:, 9])


def test_position_matters():
    """the same tokens in a different order give different predictions (position embeddings are used)"""
    m = make(T=8).eval()
    torch.nn.init.normal_(m.pos_emb.weight, std=1.0)
    x = torch.tensor([[1, 2, 3, 4, 5, 6, 7, 8]])
    perm = torch.tensor([[8, 7, 6, 5, 4, 3, 2, 1]])
    a = m(x)[0][0, -1]; b = m(perm)[0][0, -1]
    assert not torch.allclose(a, b, atol=1e-3)


def test_can_overfit_one_batch():
    """a small GPT memorises one random batch: loss from ln V to below 0.15 in 250 AdamW steps"""
    torch.manual_seed(0)
    V, T = 30, 16
    m = G.GPT(V, T, 2, 2, 32)
    x, y = torch.randint(0, V, (4, T)), torch.randint(0, V, (4, T))
    opt = torch.optim.AdamW(m.parameters(), lr=3e-3)
    first = None
    for step in range(250):
        _, loss = m(x, y)
        first = loss.item() if first is None else first
        opt.zero_grad(); loss.backward(); opt.step()
    assert abs(first - math.log(V)) < 0.15
    assert loss.item() < 0.15, "final loss %.3f: the model cannot even memorise one batch" % loss.item()


def test_dropout_only_in_training():
    """with dropout > 0 two forward passes differ in train mode and agree in eval mode"""
    m = make(dropout=0.2)
    x = torch.randint(0, 65, (2, 8))
    m.eval()
    assert torch.equal(m(x)[0], m(x)[0])
    m.train()
    assert not torch.equal(m(x)[0], m(x)[0])
