# Solution notes

- The forward pass is five lines; the work is the backward one. Writing `xhat = (x - mean) * rstd` makes the gradient expressible in terms of `xhat` and `rstd` only, so the cache is three arrays.
- The mean-subtraction in `dx` removes the part of the gradient that would just shift the whole row (the mean is normalised away), and the `xhat * mean(dxhat * xhat)` term removes the part that would just rescale it. Both directions have no effect on the output, so they must carry no gradient.
- `ln_report.py` shows the point: with a weight scale of 0.02 the plain 20-layer stack has a signal of about 1e-13 at the last layer (from 0.23 at the first); with layer norm every layer sees std 1.000 whatever the scale (0.02, 0.1, 0.3 or 1).
- Part C is complete: you can now write, differentiate and train a small neural language model without a framework. PyTorch does exactly this for you in Part D.
