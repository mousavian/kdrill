"""Lesson 20 - reference solution."""
import torch
import torch.nn as nn
import torch.nn.functional as F

from attention import Head


class MultiHeadAttention(nn.Module):
    def __init__(self, n_embd, n_head, block_size, dropout=0.0):
        super().__init__()
        if n_embd % n_head != 0:
            raise ValueError("n_embd must be divisible by n_head")
        self.heads = nn.ModuleList([Head(n_embd, n_embd // n_head, block_size, dropout) for _ in range(n_head)])
        self.proj = nn.Linear(n_embd, n_embd)
        self.dropout = nn.Dropout(dropout)

    def forward(self, x):
        out = torch.cat([h(x) for h in self.heads], dim=-1)
        return self.dropout(self.proj(out))


class FeedForward(nn.Module):
    def __init__(self, n_embd, dropout=0.0):
        super().__init__()
        self.fc1 = nn.Linear(n_embd, 4 * n_embd)
        self.fc2 = nn.Linear(4 * n_embd, n_embd)
        self.dropout = nn.Dropout(dropout)

    def forward(self, x):
        return self.dropout(self.fc2(F.gelu(self.fc1(x))))


class Block(nn.Module):
    def __init__(self, n_embd, n_head, block_size, dropout=0.0):
        super().__init__()
        self.ln1 = nn.LayerNorm(n_embd)
        self.attn = MultiHeadAttention(n_embd, n_head, block_size, dropout)
        self.ln2 = nn.LayerNorm(n_embd)
        self.ffn = FeedForward(n_embd, dropout)

    def forward(self, x):
        x = x + self.attn(self.ln1(x))
        return x + self.ffn(self.ln2(x))


def block_param_count(n_embd):
    C = n_embd
    attn = 3 * C * C + (C * C + C)            # q, k, v (no bias) + output projection
    ffn = (C * 4 * C + 4 * C) + (4 * C * C + C)
    norms = 2 * (2 * C)
    return attn + ffn + norms                  # = 12 C^2 + 10 C
