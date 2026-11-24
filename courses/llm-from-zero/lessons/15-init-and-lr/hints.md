`make_params`: one `rng = np.random.default_rng(seed)`, draw `C`, then `W1`, then `W2`, each `rng.normal(size=shape)`, then multiply `W1` by `w1_scale` (default `kaiming_scale(context * d_emb)`) and `W2` by `w2_scale`. Biases are zeros.
---
`hidden_stats`: replicate the forward pass up to the hidden layer: `flat = params["C"][X].reshape(len(X), -1)`, `h = np.tanh(flat @ W1 + b1)`; then `h.mean()`, `h.std()` and `(np.abs(h) > 0.97).mean()`. `update_ratio`: loop over `params` and skip arrays with `ndim < 2`.
---
`lr_range_test`: copy params (`{k: v.copy() ...}`); for `i in range(steps)`: `lr = lo * (hi / lo) ** (i / (steps - 1))`, draw the batch, run `mlp_lm.forward` and `backward`, append `(lr, loss)` BEFORE updating, stop (after the append) if `not np.isfinite(loss) or loss > 4 * first_loss`, otherwise update the copy. `suggest_lr`: filter the rows to finite losses, take the one with the smallest loss, return its lr divided by 10.
