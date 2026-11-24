# 19 - Self-attention, one causal head

## Concept

The MLP of lesson 14 reads a fixed window of the last three characters, always the same way.
Language needs something more flexible: the right word to look at might be the previous one or
one fifty tokens back, and which it is depends on the content. **Self-attention** lets every
position decide for itself which earlier positions to read from.

Build it in two steps. **Step 1: average the past.** Position `t` could simply take the mean of
the vectors at positions `0..t`. As a matrix product that is a lower-triangular matrix whose
rows sum to 1, times the sequence: `out = W @ x`. The lower-triangular shape *is* causality:
row `t` has zeros after column `t`, so nothing from the future can leak in. (Predicting token
`t+1` while allowed to see token `t+1` would be cheating, and the model would "learn" to copy.)

**Step 2: learn the weights.** Instead of equal weights, let each position compute from its
own vector a **query** ("what am I looking for?") and let every position publish a **key**
("what do I contain?") and a **value** ("what I will hand over"), each by a learned linear map.
The score between position `t` and an earlier position `s` is the dot product `q_t . k_s`,
large when they match. Divide by `sqrt(head_size)`: without it the dot products grow with the
dimension, the softmax saturates into a near one-hot, and gradients vanish. Mask the future
with `-inf` (softmax turns it into exactly 0), take a softmax over positions to get weights that
sum to 1, and return the weighted sum of the values:

    out = softmax(mask(Q K^T / sqrt(hs))) V        shapes: (B,T,hs) (B,T,hs)^T -> (B,T,T) -> (B,T,hs)

That is the whole mechanism. A transformer is many such heads, side by side and stacked
(lesson 20). Check shapes constantly: most attention bugs are a transposed dimension.

## The situation

`attention.py` has three pieces to write: `causal_mean` (step 1), `causal_attention` (the
function), and `Head` (the module). It forbids the library versions (`MultiheadAttention`,
`scaled_dot_product_attention`, `nn.Transformer*`): the point is to write it once yourself.
`attention_demo.py` prints the attention weights of a random head.

## Your task

Implement `causal_mean`, `causal_attention` and `Head` (`key`, `query`, `value` as bias-free
`nn.Linear`, a dropout module, `self.att`). Verify checks `causal_mean` against loops, the
attention function against the formula (lower-triangular weights, rows summing to 1), the
scaling, dropout only on the weights and only in training mode, the module's structure and
output against the formula with its own weights, **causality** (changing future tokens never
changes earlier outputs), gradients, and a one-token sequence. It also scans your source for
the forbidden library calls.

## Useful commands

- `make py F=attention_demo.py`
- `kdrill hint`; `kdrill solution`.

## On a real project

You would call `F.scaled_dot_product_attention` (it dispatches to fused FlashAttention kernels,
much faster and lighter on memory) and `is_causal=True`; now you know what it computes.

## Read more

- Attention Is All You Need: https://arxiv.org/abs/1706.03762
- The Illustrated Transformer: https://jalammar.github.io/illustrated-transformer/
- `torch.nn.functional.scaled_dot_product_attention`: https://pytorch.org/docs/stable/generated/torch.nn.functional.scaled_dot_product_attention.html
