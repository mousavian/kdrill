"""Lesson 19 - one head of causal self-attention, written by hand (PyTorch).

Not allowed: torch.nn.MultiheadAttention, F.scaled_dot_product_attention, nn.Transformer*.
Shapes: B = batch, T = sequence length (<= block_size), C = n_embd, hs = head_size.
"""
import math

import torch
import torch.nn as nn
import torch.nn.functional as F


def causal_mean(x):
    """x: (B, T, C). Return (B, T, C) where out[b, t] is the MEAN of x[b, 0..t] (position t
    and everything before it). Do it with one matrix product: a lower-triangular (T, T) matrix
    whose rows are normalised to sum to 1 (torch.tril, then divide by the row sums), times x.
    This is attention with identical weights on the past."""
    # TODO
    raise NotImplementedError


def causal_attention(q, k, v, dropout=None):
    """Scaled dot-product attention with a causal mask.
    q, k, v: (B, T, hs). scores = q @ k^T / sqrt(hs), shape (B, T, T); a position may only
    attend to itself and EARLIER positions: set the scores of later positions to -inf before
    the softmax (softmax over the last dimension). If `dropout` (an nn.Dropout) is given,
    apply it to the attention weights before multiplying with v.
    Return (out, att): out = att @ v of shape (B, T, hs), and att the weights BEFORE dropout,
    shape (B, T, T) (each row sums to 1, zeros above the diagonal)."""
    # TODO
    raise NotImplementedError


class Head(nn.Module):
    """One attention head.

    Attributes (the tests use these names): self.key, self.query, self.value are
    nn.Linear(n_embd, head_size, bias=False); self.dropout = nn.Dropout(dropout).
    forward(x): x is (B, T, n_embd) with T <= block_size; returns (B, T, head_size) and
    stores the attention weights (before dropout) in self.att.
    """

    def __init__(self, n_embd, head_size, block_size, dropout=0.0):
        super().__init__()
        self.block_size = block_size
        # TODO: key, query, value, dropout
        raise NotImplementedError

    def forward(self, x):
        # TODO: project, call causal_attention, remember att
        raise NotImplementedError
