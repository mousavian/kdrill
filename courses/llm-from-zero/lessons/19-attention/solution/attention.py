"""Lesson 19 - reference solution."""
import math

import torch
import torch.nn as nn
import torch.nn.functional as F


def causal_mean(x):
    T = x.shape[1]
    w = torch.tril(torch.ones(T, T, dtype=x.dtype, device=x.device))
    w = w / w.sum(dim=1, keepdim=True)
    return w @ x


def causal_attention(q, k, v, dropout=None):
    T, hs = q.shape[1], q.shape[2]
    scores = q @ k.transpose(-2, -1) / math.sqrt(hs)
    mask = torch.tril(torch.ones(T, T, dtype=torch.bool, device=q.device))
    scores = scores.masked_fill(~mask, float("-inf"))
    att = F.softmax(scores, dim=-1)
    w = dropout(att) if dropout is not None else att
    return w @ v, att


class Head(nn.Module):
    def __init__(self, n_embd, head_size, block_size, dropout=0.0):
        super().__init__()
        self.block_size = block_size
        self.key = nn.Linear(n_embd, head_size, bias=False)
        self.query = nn.Linear(n_embd, head_size, bias=False)
        self.value = nn.Linear(n_embd, head_size, bias=False)
        self.dropout = nn.Dropout(dropout)

    def forward(self, x):
        out, att = causal_attention(self.query(x), self.key(x), self.value(x), self.dropout)
        self.att = att
        return out
