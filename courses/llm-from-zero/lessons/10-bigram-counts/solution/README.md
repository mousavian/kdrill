# Solution notes

- `np.bincount(a * V + b)` is the counting trick: every pair maps to one flat cell, `reshape(V, V)` turns it back into a matrix.
- Unseen-context rows are made uniform instead of dividing 0 by 0; with `smoothing > 0` the problem does not occur.
- Look at `m.probs()` as an image or print a few rows: this table is the entire model, `V * V` numbers. A neural bigram (lesson 13) has exactly the same number of parameters.
- Compare the text for smoothing 0 and 1: smoothing barely changes sampled text but matters enormously for the loss on unseen data (next lesson).
