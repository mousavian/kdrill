"""The model and tokenizer of llm-from-zero, in one file (the reference solutions, unchanged).

Your own gpt.py / transformer.py / attention.py / bpe.py from that course define exactly these
classes with exactly these parameter names, so a capstone checkpoint loads here. This copy is what
the fine-tuning lessons import, so that this course does not depend on your earlier files.
"""
import math
import re
from collections import Counter

import torch
import torch.nn as nn
import torch.nn.functional as F


# ---- attention.py (lesson 19)
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


# ---- transformer.py (lesson 20)
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


# ---- gpt.py (lesson 21)
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


# ---- bpe.py (lesson 08)
PRETOKEN = re.compile(r" ?[A-Za-z]+| ?[0-9]+| ?[^\sA-Za-z0-9]+|\s+(?!\S)|\s+")


def pretokenize(text):
    return PRETOKEN.findall(text)


def split_on_specials(text, specials):
    if not specials:
        return [(text, False)] if text else []
    pat = "(" + "|".join(re.escape(s) for s in sorted(specials, key=len, reverse=True)) + ")"
    return [(part, i % 2 == 1) for i, part in enumerate(re.split(pat, text)) if part != ""]


def merge_pair(ids, pair, new_id):
    out, i, n = [], 0, len(ids)
    a, b = pair
    while i < n:
        if i < n - 1 and ids[i] == a and ids[i + 1] == b:
            out.append(new_id)
            i += 2
        else:
            out.append(ids[i])
            i += 1
    return out


def count_pairs(chunk_counts):
    pc = Counter()
    for chunk, c in chunk_counts.items():
        for pair in zip(chunk, chunk[1:]):
            pc[pair] += c
    return pc


class BPE:
    def __init__(self, merges=(), special_tokens=()):
        self.merges = [tuple(m) for m in merges]
        self.special_tokens = list(special_tokens)
        self.rank = {p: i for i, p in enumerate(self.merges)}
        self.special_ids = {s: 256 + len(self.merges) + i for i, s in enumerate(self.special_tokens)}
        self._cache = {}
        self._bytes = {i: bytes([i]) for i in range(256)}
        for k, (a, b) in enumerate(self.merges):
            self._bytes[256 + k] = self._bytes[a] + self._bytes[b]
        for s, i in self.special_ids.items():
            self._bytes[i] = s.encode("utf-8")

    @property
    def vocab_size(self):
        return 256 + len(self.merges) + len(self.special_tokens)

    @classmethod
    def train(cls, text, num_merges, special_tokens=("<|endoftext|>",)):
        counts = Counter()
        for piece, is_special in split_on_specials(text, special_tokens):
            if is_special:
                continue
            for chunk in pretokenize(piece):
                counts[tuple(chunk.encode("utf-8"))] += 1
        merges = []
        for _ in range(num_merges):
            pc = count_pairs(counts)
            if not pc:
                break
            pair, n = max(pc.items(), key=lambda kv: (kv[1], -kv[0][0], -kv[0][1]))
            if n < 2:
                break
            new_id = 256 + len(merges)
            merges.append(pair)
            new_counts = Counter()
            for chunk, c in counts.items():
                new_counts[tuple(merge_pair(chunk, pair, new_id))] += c
            counts = new_counts
        return cls(merges, special_tokens)

    def token_bytes(self, token_id):
        try:
            return self._bytes[int(token_id)]
        except KeyError:
            raise ValueError("unknown token id %r" % (token_id,)) from None

    def _encode_chunk(self, chunk_bytes):
        hit = self._cache.get(chunk_bytes)
        if hit is not None:
            return hit
        ids = list(chunk_bytes)
        while len(ids) >= 2:
            best = min(((self.rank.get(p, 1 << 60), p) for p in zip(ids, ids[1:])), key=lambda rp: rp[0])
            if best[0] == 1 << 60:
                break
            ids = merge_pair(ids, best[1], 256 + best[0])
        self._cache[chunk_bytes] = ids
        return ids

    def encode(self, text):
        out = []
        for piece, is_special in split_on_specials(text, self.special_tokens):
            if is_special:
                out.append(self.special_ids[piece])
            else:
                for chunk in pretokenize(piece):
                    out.extend(self._encode_chunk(chunk.encode("utf-8")))
        return out

    def decode(self, ids):
        return b"".join(self.token_bytes(i) for i in ids).decode("utf-8", errors="replace")

    def to_dict(self):
        return {"type": "bpe", "merges": [list(m) for m in self.merges], "special_tokens": list(self.special_tokens)}

    @classmethod
    def from_dict(cls, d):
        return cls(d["merges"], d["special_tokens"])
