# 20 - The transformer block

## Concept

One attention head (lesson 19) looks at the past in one way. A **multi-head** layer runs several
heads in parallel, each with its own query, key and value maps and a smaller size
(`head_size = n_embd / n_head`), so different heads can specialise: one tracks the previous
word, another the subject of the sentence, another quotation marks. Their outputs are
concatenated back to `n_embd` numbers and mixed by a learned **output projection**.

Attention moves information *between* positions. The **feed-forward network** then processes each
position on its own: a two-layer MLP that widens to `4 * n_embd`, applies a non-linearity (GELU) and
narrows back. Most of the parameters of a transformer live here.

The **block** stacks the two, with two ingredients that make deep stacks trainable:

- **Residual connections**: `x = x + sublayer(x)`. Each sub-layer only has to learn a *correction*
  to what is already there, gradients flow straight through the `+`, and a block whose sub-layers
  output zero is the identity (a test checks it). Without residuals a 12-layer network is very
  hard to train.
- **Layer norm before each sub-layer** (*pre-norm*): `x = x + attn(ln1(x))`. The original paper
  normalised after the residual (post-norm); pre-norm trains more stably without careful warm-up and
  is what GPT-2 and later models use. LayerNorm is lesson 16 in PyTorch clothes.

Finally, **count the parameters** before you let code do it. For width `C`: attention has `3C^2`
(key/query/value of all heads together, no bias) plus the projection `C^2 + C`; the feed-forward
layers have `C*4C + 4C` and `4C*C + C`; two LayerNorms have `2C` each. Being able to predict a
model's size from its hyperparameters is how you decide what fits in memory before you train.

## The situation

`transformer.py` imports your `Head` and has `MultiHeadAttention`, `FeedForward`, `Block` and
`block_param_count` to write. Attribute names (`heads`, `proj`, `fc1`, `fc2`, `ln1`, `attn`,
`ln2`, `ffn`) are fixed because later lessons and the tests use them.

## Your task

Implement the three modules and `block_param_count(n_embd)`. Verify checks the structure and
output of multi-head attention (including the divisibility error), that heads have separate weights,
the feed-forward formula and that it never mixes positions, the pre-norm residual wiring, the
identity property, causality, dropout behaviour, and that your hand-derived parameter formula
equals the real count for several sizes and works for `n_embd = 4096` without building anything.
The library attention is forbidden.

## Useful commands

- `kdrill py`: `from transformer import Block; sum(p.numel() for p in Block(64, 4, 32).parameters())`
- `kdrill hint`; `kdrill solution`.

## On a real project

Production blocks add rotary position embeddings, grouped-query attention, RMSNorm and SwiGLU
feed-forward layers; each is a small change to this structure.

## Read more

- Attention Is All You Need: https://arxiv.org/abs/1706.03762
- On Layer Normalization in the Transformer Architecture (pre-norm): https://arxiv.org/abs/2002.04745
- Deep Residual Learning for Image Recognition: https://arxiv.org/abs/1512.03385
