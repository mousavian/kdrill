`forward`: `emb = C[X]` is `(N, context, d)`; `flat = emb.reshape(N, -1)`; `h = np.tanh(flat @ W1 + b1)`; `logits = h @ W2 + b2`. Loss by log-sum-exp as in lesson 13. Keep `X, Y, flat, h, probs` in the cache.
---
`backward`, top to bottom: `dlogits = (probs - onehot) / N`; `dW2 = h.T @ dlogits`; `db2 = dlogits.sum(0)`; `dh = dlogits @ W2.T`; `dhpre = dh * (1 - h**2)`; `dW1 = flat.T @ dhpre`; `db1 = dhpre.sum(0)`; `dflat = dhpre @ W1.T`; reshape it to `(N, context, d)`; `dC = zeros_like(C)` and `np.add.at(dC, X, demb)`.
---
If a gradient check fails, test one parameter at a time, bottom-up: `b2` and `W2` first (they depend only on the loss), then `b1` and `W1`, then `C`. `train`: `idx = rng.integers(0, N, batch_size)`, forward/backward on `X[idx], Y[idx]`, then `params[k] -= lr * grads[k]` for every key (in place, so the caller's dict changes). For `evaluate_loss`, weight each chunk's loss by its size before dividing by `N`.
