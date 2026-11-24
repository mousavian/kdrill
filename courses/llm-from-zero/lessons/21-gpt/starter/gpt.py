"""Lesson 21 - a GPT (PyTorch). Builds on Block and block_param_count from your transformer.py.

Not allowed: nn.TransformerDecoder / nn.Transformer*, MultiheadAttention, scaled_dot_product_attention.
"""
import math

import torch
import torch.nn as nn
import torch.nn.functional as F

from transformer import Block, block_param_count


class GPT(nn.Module):
    """A decoder-only transformer language model.

    Attributes (fixed names): tok_emb = nn.Embedding(vocab_size, n_embd), pos_emb =
    nn.Embedding(block_size, n_embd), drop = nn.Dropout(dropout), blocks = nn.ModuleList of
    n_layer Blocks, ln_f = nn.LayerNorm(n_embd), lm_head = nn.Linear(n_embd, vocab_size, bias=False)
    whose weight is TIED to tok_emb.weight (the very same Parameter object).

    Initialisation (after building everything, GPT-2 style): every nn.Linear and nn.Embedding
    weight ~ normal(0, 0.02), every bias 0; then the weights of the residual projections
    (attn.proj in every block and ffn.fc2 in every block) ~ normal(0, 0.02 / sqrt(2 * n_layer)),
    so the residual stream does not grow with depth. LayerNorm keeps its default (1 and 0).
    """

    def __init__(self, vocab_size, block_size, n_layer, n_head, n_embd, dropout=0.0):
        super().__init__()
        self.block_size = block_size
        # TODO: build the layers, tie the weights, initialise
        raise NotImplementedError

    def forward(self, idx, targets=None):
        """idx: (B, T) LongTensor, T <= block_size (else ValueError). Token embedding plus
        position embedding of positions 0..T-1, dropout, the blocks, ln_f, lm_head.
        Return (logits, loss): logits (B, T, vocab_size); loss is the mean cross-entropy against
        targets (B, T), or None when targets is None."""
        # TODO
        raise NotImplementedError

    def num_params(self, non_embedding=False):
        """Number of parameters, each shared (tied) parameter counted once. With
        non_embedding=True subtract the position embedding's parameters."""
        # TODO
        raise NotImplementedError


def gpt_param_count(vocab_size, block_size, n_layer, n_embd):
    """The number of parameters of a GPT from its hyperparameters alone (a formula, using
    block_param_count). The tied output layer adds nothing; the final LayerNorm has a scale and a shift."""
    # TODO
    raise NotImplementedError
