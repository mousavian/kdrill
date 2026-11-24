# Solution notes

- `torch.cat([h(x) for h in heads], dim=-1)` restores width `n_embd` because `n_head * head_size == n_embd`; the projection then lets the heads mix.
- Pre-norm residual: normalise only the *input of the sub-layer*; the residual stream itself is never normalised, which keeps a clean path for gradients from the last layer to the first.
- Hand count: attention `3C^2 + C^2 + C`, feed-forward `8C^2 + 5C`, norms `4C`: **12 C^2 + 10 C** in total. For C = 1000 that is 12,010,000 parameters per block, so a 12-block model at that width has about 144 million parameters in its blocks alone.
- Note what is NOT in a block: token and position embeddings and the final norm and output layer, which come with the full GPT next.
