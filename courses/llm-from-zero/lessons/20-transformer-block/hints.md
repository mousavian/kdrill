`MultiHeadAttention`: `nn.ModuleList([Head(n_embd, n_embd // n_head, block_size, dropout) for _ in range(n_head)])`; forward: `torch.cat([h(x) for h in self.heads], dim=-1)`, then `self.proj`, then dropout. Raise `ValueError` first if `n_embd % n_head != 0`. `FeedForward.forward`: `self.dropout(self.fc2(F.gelu(self.fc1(x))))`.
---
`Block.forward` is two lines: `x = x + self.attn(self.ln1(x))` and `x = x + self.ffn(self.ln2(x))`. If the identity test fails, the `+ x` is probably missing or the norm is applied to the wrong tensor.
---
Count by hand, per part: q, k, v maps (no bias): `3 * C * C`; projection: `C * C + C`; `fc1`: `C * 4C + 4C`; `fc2`: `4C * C + C`; each LayerNorm: `2C`, two of them. Add up and simplify to `a*C**2 + b*C`, then compare with `sum(p.numel() for p in Block(C, H, 16).parameters())` for a couple of `C`.
