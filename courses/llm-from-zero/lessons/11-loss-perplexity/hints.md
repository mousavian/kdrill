`nll`: `p = P[ids[:-1], ids[1:]]` picks the probability of every actual transition in one fancy-indexing step. If `p.min() <= 0` return `float("inf")` before taking any log (that avoids the numpy warning); otherwise `-np.log(p).mean()`. Return a Python `float`.
---
`perplexity` is `math.exp(loss)` except when the loss is infinite (`math.isinf`). `smoothing_sweep`: for each `k`, `BigramModel(V, k).fit(train_ids).probs()` once, then `nll` of that matrix on the train ids and on the validation ids.
---
`best_smoothing`: `min(rows, key=lambda r: (r[2], r[0]))[0]`: lowest validation loss first, smaller k on a tie. In the report, notice that the first column (train loss) keeps improving as `k` shrinks while the validation column does not: that gap is overfitting.
