`causal_mean`: `w = torch.tril(torch.ones(T, T))`, `w = w / w.sum(dim=1, keepdim=True)`, `out = w @ x`; broadcasting handles the batch dimension. Check row 0: it must equal `x[:, 0]`.
---
`causal_attention`: `scores = q @ k.transpose(-2, -1) / math.sqrt(hs)`; build `mask = torch.tril(torch.ones(T, T, dtype=torch.bool))`; `scores = scores.masked_fill(~mask, float("-inf"))`; `att = F.softmax(scores, dim=-1)`; apply `dropout` to a copy of `att` for the product only; return `(w @ v, att)`.
---
`Head`: three `nn.Linear(n_embd, head_size, bias=False)` called `key`, `query`, `value`, and `nn.Dropout(dropout)`. `forward(x)`: `q, k, v = self.query(x), self.key(x), self.value(x)`, call your function with `self.dropout`, store `self.att = att` and return the output. Because the mask is built from the actual `T` of the input, any `T <= block_size` works.
