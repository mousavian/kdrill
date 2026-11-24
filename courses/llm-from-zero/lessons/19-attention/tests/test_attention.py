import math

import pytest
import torch
import torch.nn as nn

import attention
from kdlib import kdtest


def test_library_attention_is_not_used():
    """attention is written by you: no MultiheadAttention, scaled_dot_product_attention or nn.Transformer*"""
    kdtest.assert_not_used("attention", {"MultiheadAttention", "scaled_dot_product_attention", "TransformerEncoderLayer",
                                          "TransformerDecoderLayer", "Transformer", "TransformerEncoder", "TransformerDecoder",
                                          "is_causal", "flash_attn", "multi_head_attention_forward"})


def test_causal_mean():
    """causal_mean[b, t] is the mean of x[b, :t+1], in one matrix product, for any T"""
    torch.manual_seed(0)
    for T in (1, 2, 7):
        x = torch.randn(3, T, 5)
        out = attention.causal_mean(x)
        ref = torch.stack([x[:, :t + 1].mean(dim=1) for t in range(T)], dim=1)
        assert out.shape == x.shape and torch.allclose(out, ref, atol=1e-6)


def test_causal_attention_matches_reference():
    """causal_attention equals softmax(mask(q k^T / sqrt(hs))) v; att is lower-triangular with rows summing to 1"""
    torch.manual_seed(1)
    q, k, v = (torch.randn(2, 6, 8) for _ in range(3))
    out, att = attention.causal_attention(q, k, v)
    s = q @ k.transpose(1, 2) / math.sqrt(8)
    s = s.masked_fill(torch.triu(torch.ones(6, 6, dtype=torch.bool), 1), float("-inf"))
    ref_att = torch.softmax(s, dim=-1)
    assert att.shape == (2, 6, 6) and out.shape == (2, 6, 8)
    assert torch.allclose(att, ref_att, atol=1e-6) and torch.allclose(out, ref_att @ v, atol=1e-6)
    assert torch.allclose(att.sum(-1), torch.ones(2, 6), atol=1e-6) and torch.all(torch.triu(att, 1) == 0)
    assert torch.isfinite(out).all()


def test_scaling_matters():
    """the scores are divided by sqrt(head_size): with large head size the weights must not collapse to one-hot"""
    torch.manual_seed(2)
    q, k, v = (torch.randn(1, 8, 256) for _ in range(3))
    _, att = attention.causal_attention(q, k, v)
    # with the scaling, the last row spreads over several positions; unscaled it would be nearly one-hot
    assert att[0, -1].max() < 0.9


def test_dropout_acts_on_weights_only_in_training():
    """dropout is applied to the attention weights (not to the returned att) and only when the module is in train mode"""
    torch.manual_seed(3)
    d = nn.Dropout(0.5)
    q, k, v = (torch.randn(2, 6, 8) for _ in range(3))
    _, att_nodrop = attention.causal_attention(q, k, v)
    out_a, att_a = attention.causal_attention(q, k, v, d)
    assert torch.allclose(att_a, att_nodrop), "the returned weights are the ones BEFORE dropout"
    ref = att_nodrop @ v
    assert not torch.allclose(out_a, ref), "dropout was not applied to the weights"
    d.eval()
    out_b, _ = attention.causal_attention(q, k, v, d)
    assert torch.allclose(out_b, ref, atol=1e-6)


def test_head_structure_and_shape():
    """Head has key/query/value Linear layers without bias and returns (B, T, head_size) for any T <= block_size"""
    h = attention.Head(n_embd=12, head_size=5, block_size=9)
    for name in ("key", "query", "value"):
        lin = getattr(h, name)
        assert isinstance(lin, nn.Linear) and lin.bias is None and lin.weight.shape == (5, 12), name
    assert isinstance(h.dropout, nn.Dropout)
    for T in (1, 4, 9):
        assert h(torch.randn(2, T, 12)).shape == (2, T, 5)
    assert sum(p.numel() for p in h.parameters()) == 3 * 12 * 5


def test_head_equals_the_formula_with_its_own_weights():
    """with its own key/query/value weights the head computes the textbook attention output"""
    torch.manual_seed(4)
    h = attention.Head(10, 6, 8).eval()
    x = torch.randn(3, 7, 10)
    out = h(x)
    q, k, v = h.query(x), h.key(x), h.value(x)
    s = (q @ k.transpose(1, 2) / math.sqrt(6)).masked_fill(torch.triu(torch.ones(7, 7, dtype=torch.bool), 1), float("-inf"))
    assert torch.allclose(out, torch.softmax(s, -1) @ v, atol=1e-6)
    assert h.att.shape == (3, 7, 7) and torch.allclose(h.att.sum(-1), torch.ones(3, 7), atol=1e-6)


def test_causality():
    """changing tokens after position t never changes the output at positions <= t; changing earlier ones does"""
    torch.manual_seed(5)
    h = attention.Head(8, 4, 10).eval()
    x = torch.randn(2, 10, 8)
    base = h(x)
    for t in (0, 3, 8):
        y = x.clone()
        y[:, t + 1:] = torch.randn_like(y[:, t + 1:])
        assert torch.allclose(h(y)[:, :t + 1], base[:, :t + 1], atol=1e-6), "position <= %d saw the future" % t
    z = x.clone(); z[:, 0] += 1.0
    assert not torch.allclose(h(z)[:, 5], base[:, 5])


def test_gradients_flow_and_no_nan():
    """backward works and reaches all three projections; a one-token sequence has no NaN"""
    torch.manual_seed(6)
    h = attention.Head(6, 3, 5)
    h(torch.randn(2, 5, 6)).sum().backward()
    assert all(p.grad is not None and p.grad.abs().sum() > 0 for p in h.parameters())
    out = h(torch.randn(1, 1, 6))
    assert torch.isfinite(out).all()
