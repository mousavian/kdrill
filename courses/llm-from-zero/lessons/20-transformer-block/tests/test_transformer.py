import torch
import torch.nn as nn
import torch.nn.functional as F
import pytest

import transformer as T
from kdlib import kdtest


def test_no_library_attention():
    """no MultiheadAttention, scaled_dot_product_attention or nn.Transformer* in transformer.py"""
    kdtest.assert_not_used("transformer", {"MultiheadAttention", "scaled_dot_product_attention", "TransformerEncoderLayer",
                                            "TransformerDecoderLayer", "Transformer", "TransformerEncoder", "TransformerDecoder",
                                            "multi_head_attention_forward"})


def test_multihead_structure_and_output():
    """n_head heads of size n_embd // n_head, concatenated and projected; ValueError when n_embd is not divisible"""
    torch.manual_seed(0)
    m = T.MultiHeadAttention(12, 3, 8).eval()
    assert len(m.heads) == 3 and all(h.key.weight.shape == (4, 12) for h in m.heads)
    assert isinstance(m.proj, nn.Linear) and m.proj.weight.shape == (12, 12) and m.proj.bias is not None
    x = torch.randn(2, 5, 12)
    assert m(x).shape == (2, 5, 12)
    assert torch.allclose(m(x), m.proj(torch.cat([h(x) for h in m.heads], dim=-1)), atol=1e-6)
    with pytest.raises(ValueError):
        T.MultiHeadAttention(10, 3, 8)


def test_heads_are_different_and_independent():
    """each head has its own weights (not one head repeated)"""
    m = T.MultiHeadAttention(16, 4, 8)
    ws = [h.query.weight for h in m.heads]
    assert len({id(w) for w in ws}) == 4 and not torch.allclose(ws[0], ws[1])


def test_feedforward():
    """FeedForward is Linear(C, 4C) -> GELU -> Linear(4C, C) (-> dropout), position by position"""
    torch.manual_seed(1)
    f = T.FeedForward(8).eval()
    assert f.fc1.weight.shape == (32, 8) and f.fc2.weight.shape == (8, 32)
    x = torch.randn(3, 4, 8)
    assert torch.allclose(f(x), f.fc2(F.gelu(f.fc1(x))), atol=1e-6)
    y = x.clone(); y[:, 2] += 5
    assert torch.allclose(f(y)[:, 0], f(x)[:, 0]) and not torch.allclose(f(y)[:, 2], f(x)[:, 2]), "position-wise: no mixing between positions"


def test_block_is_pre_norm_residual():
    """Block computes x + attn(ln1(x)) then + ffn(ln2(x)), with LayerNorm before each sub-layer"""
    torch.manual_seed(2)
    b = T.Block(16, 4, 8).eval()
    assert isinstance(b.ln1, nn.LayerNorm) and isinstance(b.ln2, nn.LayerNorm) and b.ln1.normalized_shape == (16,)
    x = torch.randn(2, 6, 16)
    y = x + b.attn(b.ln1(x))
    ref = y + b.ffn(b.ln2(y))
    assert torch.allclose(b(x), ref, atol=1e-6)


def test_residual_path_is_an_identity_when_sublayers_output_zero():
    """with the attention projection and the last feed-forward layer zeroed, the block returns its input exactly"""
    torch.manual_seed(3)
    b = T.Block(8, 2, 8).eval()
    with torch.no_grad():
        b.attn.proj.weight.zero_(); b.attn.proj.bias.zero_()
        b.ffn.fc2.weight.zero_(); b.ffn.fc2.bias.zero_()
    x = torch.randn(2, 5, 8)
    assert torch.equal(b(x), x)


def test_block_is_causal():
    """changing later tokens never changes earlier outputs of a block"""
    torch.manual_seed(4)
    b = T.Block(16, 4, 10).eval()
    x = torch.randn(2, 10, 16)
    y = x.clone(); y[:, 6:] = torch.randn_like(y[:, 6:])
    assert torch.allclose(b(y)[:, :6], b(x)[:, :6], atol=1e-5)


def test_dropout_only_in_training():
    """in eval mode two forward passes agree; in train mode with dropout they differ"""
    torch.manual_seed(5)
    b = T.Block(16, 4, 8, dropout=0.3)
    x = torch.randn(2, 6, 16)
    b.eval()
    assert torch.equal(b(x), b(x))
    b.train()
    assert not torch.equal(b(x), b(x))


def test_parameter_count_by_hand_equals_by_code():
    """block_param_count(n_embd) equals the real number of parameters of a Block, for several sizes, and works for huge n_embd instantly"""
    for C, H in [(8, 2), (32, 4), (48, 6), (64, 8)]:
        real = sum(p.numel() for p in T.Block(C, H, 16).parameters())
        assert T.block_param_count(C) == real, (C, T.block_param_count(C), real)
    assert T.block_param_count(4096) == 12 * 4096 ** 2 + 10 * 4096, "block_param_count must be a formula in n_embd, not a count of a built model"
    assert T.block_param_count(1000) == 12_010_000
