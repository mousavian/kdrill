# Solution notes

- `d loss / d logits = (p - onehot) / n` is the entire derivation. `np.add.at` routes each sample's gradient to the row of its input; plain fancy-index assignment `dW[X] += d` would silently drop repeated rows.
- The loss uses log-sum-exp; the probabilities are only needed for the gradient. Mixing them up (`log(probs)`) is correct on easy inputs and `inf` on hard ones.
- Full-batch descent with `lr = 15` is stable here because each row only receives a fraction of the total gradient; the right step size depends on the problem, which is why lesson 15 searches for it.
- After training, `probs_from_weights(W)` and the count table agree to about two decimals: two ways to get the same model. The neural version generalises to models counting cannot represent (next lessons).
