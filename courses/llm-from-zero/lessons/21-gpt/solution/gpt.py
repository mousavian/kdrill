"""Lesson 21 - reference solution."""
import math

import torch
import torch.nn as nn
import torch.nn.functional as F

from transformer import Block, block_param_count


class GPT(nn.Module):
    def __init__(self, vocab_size, block_size, n_layer, n_head, n_embd, dropout=0.0):
        super().__init__()
        self.block_size = block_size
        self.tok_emb = nn.Embedding(vocab_size, n_embd)
        self.pos_emb = nn.Embedding(block_size, n_embd)
        self.drop = nn.Dropout(dropout)
        self.blocks = nn.ModuleList([Block(n_embd, n_head, block_size, dropout) for _ in range(n_layer)])
        self.ln_f = nn.LayerNorm(n_embd)
        self.lm_head = nn.Linear(n_embd, vocab_size, bias=False)
        self.lm_head.weight = self.tok_emb.weight
        for m in self.modules():
            if isinstance(m, (nn.Linear, nn.Embedding)):
                nn.init.normal_(m.weight, mean=0.0, std=0.02)
                if getattr(m, "bias", None) is not None:
                    nn.init.zeros_(m.bias)
        for blk in self.blocks:
            for w in (blk.attn.proj.weight, blk.ffn.fc2.weight):
                nn.init.normal_(w, mean=0.0, std=0.02 / math.sqrt(2 * n_layer))

    def forward(self, idx, targets=None):
        B, T = idx.shape
        if T > self.block_size:
            raise ValueError("sequence length %d exceeds block_size %d" % (T, self.block_size))
        pos = torch.arange(T, device=idx.device)
        x = self.drop(self.tok_emb(idx) + self.pos_emb(pos))
        for blk in self.blocks:
            x = blk(x)
        logits = self.lm_head(self.ln_f(x))
        loss = None
        if targets is not None:
            loss = F.cross_entropy(logits.reshape(-1, logits.shape[-1]), targets.reshape(-1))
        return logits, loss

    def num_params(self, non_embedding=False):
        n = sum(p.numel() for p in self.parameters())
        if non_embedding:
            n -= self.pos_emb.weight.numel()
        return n


def gpt_param_count(vocab_size, block_size, n_layer, n_embd):
    return vocab_size * n_embd + block_size * n_embd + n_layer * block_param_count(n_embd) + 2 * n_embd
