`forward`: `logits = W[X]` has shape `(n, V)`. For the loss use `m = logits.max(axis=1, keepdims=True)` and `lse = m[:, 0] + np.log(np.exp(logits - m).sum(axis=1))`; the loss is `(lse - logits[np.arange(n), Y]).mean()`. Return `softmax(logits)` too; its rows are the `probs`.
---
`backward`: `d = probs.copy()`; `d[np.arange(n), Y] -= 1`; `d /= n`; this is the gradient wrt the logits of every sample. Then `dW = np.zeros((V, V)); np.add.at(dW, X, d)` puts each sample's gradient on the row of its input.
---
`train`: `X, Y = make_xy(ids)`; `W = init_weights(V, seed)`; loop `steps` times: `loss, probs = forward(W, X, Y)`, record the loss, `W -= lr * backward(probs, X, Y, V)`. If the loss goes up, your learning rate is too high or your gradient is wrong: compare with `kdtest`-style numeric differences on a tiny `V`.
