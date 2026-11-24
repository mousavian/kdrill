# 21 - The full GPT

## Concept

You have the block. A **GPT** is a short list of parts around a stack of them:

1. **Token embedding**: a table `(vocab_size, n_embd)` turning each id into a vector (as in lesson 14).
2. **Position embedding**: a second table `(block_size, n_embd)` indexed by position `0..T-1` and *added* to the
   token vectors. Attention on its own does not know order (shuffle the tokens and each position still
   attends to the same set), so position must be put into the data. This also fixes the longest sequence the model can
   take: `block_size`.
3. **`n_layer` blocks** (lesson 20).
4. **A final LayerNorm**, because pre-norm blocks leave the residual stream unnormalised.
5. **An output layer** projecting back to `vocab_size` logits.

**Weight tying**: the output layer reuses the token-embedding matrix (`lm_head.weight = tok_emb.weight`). Looking up
"which vector is this token" and scoring "which token is this vector closest to" are the same question, and sharing
saves `V * n_embd` parameters, a large share of a small model.

**Initialisation matters.** GPT-2 draws all weights from `N(0, 0.02)` and, for the layers that write into the residual
stream (attention projection and the feed-forward output), shrinks them by `1 / sqrt(2 * n_layer)`: every block adds to
the stream, and without the shrinking its variance grows with depth. With these scales the logits start near zero and
the first loss is `ln V` (lesson 15's check, applied to a transformer).

Two habits to build now. **Know your parameter count from the hyperparameters**: for width `C`, `L` layers, vocabulary `V`
and `T` positions it is `V*C + T*C + L*(block) + 2C`; for the GPT-2 small shape the formula gives 124.4 million (the
published model has 27 thousand more because its QKV maps have biases). And **overfit one batch** before training on
data: a model that cannot memorise 64 random tokens has a bug (wiring, a wrong mask, a frozen parameter), and it is
far easier to find that bug on one batch than after an hour of training.

## The situation

`gpt.py` imports `Block` and `block_param_count` from your `transformer.py`. Attribute names are fixed
(`tok_emb`, `pos_emb`, `drop`, `blocks`, `ln_f`, `lm_head`). `overfit_one_batch.py` runs the sanity check and prints the
parameter count next to your formula.

## Your task

Implement `GPT.__init__` (layers, tying, initialisation), `GPT.forward`, `GPT.num_params` and `gpt_param_count`.
Verify checks the structure and the tying (the *same* Parameter object), shapes and errors, the initial loss
(`ln V`), the initialisation scales, the parameter formula for several shapes (and for a GPT-2-small shape), causality of the
whole model, that position matters, dropout, and that a small GPT memorises one batch. `nn.Transformer*` and the library
attention are forbidden.

## Useful commands

- `make py F=overfit_one_batch.py`
- `kdrill hint`; `kdrill solution`.

## On a real project

Large models also use `torch.compile`, mixed precision (`bfloat16`) and fused attention; the architecture is what you wrote.
This is the model of nanoGPT and (with small changes) of the GPT-2 family.

## Read more

- Language Models are Unsupervised Multitask Learners (GPT-2): https://cdn.openai.com/better-language-models/language_models_are_unsupervised_multitask_learners.pdf
- Using the Output Embedding to Improve Language Models (weight tying): https://arxiv.org/abs/1608.05859
- nanoGPT: https://github.com/karpathy/nanoGPT
