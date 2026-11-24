"""Lesson 20 - the transformer block (PyTorch). Builds on Head from your attention.py.

Not allowed: nn.MultiheadAttention, F.scaled_dot_product_attention, nn.Transformer*.
"""
import torch
import torch.nn as nn
import torch.nn.functional as F

from attention import Head


class MultiHeadAttention(nn.Module):
    """n_head heads of size n_embd // n_head side by side, outputs concatenated on the last
    dimension, then a learned projection (nn.Linear(n_embd, n_embd), WITH bias) and dropout.

    Attributes: self.heads (nn.ModuleList of Head), self.proj, self.dropout.
    Raise ValueError if n_embd is not divisible by n_head."""

    def __init__(self, n_embd, n_head, block_size, dropout=0.0):
        super().__init__()
        # TODO
        raise NotImplementedError

    def forward(self, x):
        # TODO
        raise NotImplementedError


class FeedForward(nn.Module):
    """Position-wise MLP: fc1 = nn.Linear(n_embd, 4 * n_embd), GELU (F.gelu), fc2 = nn.Linear(4 * n_embd, n_embd),
    then dropout. Attributes: self.fc1, self.fc2, self.dropout."""

    def __init__(self, n_embd, dropout=0.0):
        super().__init__()
        # TODO
        raise NotImplementedError

    def forward(self, x):
        # TODO
        raise NotImplementedError


class Block(nn.Module):
    """A pre-norm transformer block:
        x = x + attn(ln1(x))
        x = x + ffn(ln2(x))
    Attributes: self.ln1, self.attn (MultiHeadAttention), self.ln2 (both nn.LayerNorm(n_embd)),
    self.ffn (FeedForward)."""

    def __init__(self, n_embd, n_head, block_size, dropout=0.0):
        super().__init__()
        # TODO
        raise NotImplementedError

    def forward(self, x):
        # TODO
        raise NotImplementedError


def block_param_count(n_embd):
    """Number of parameters of one Block, from a formula in n_embd alone (do NOT build a
    Block to count: work it out on paper first). Count: the bias-free key/query/value maps of all
    heads together, the attention output projection, the feed-forward layers, two LayerNorms
    (each has a scale and a shift)."""
    # TODO
    raise NotImplementedError
