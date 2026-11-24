# Solution notes

- `P[ids[:-1], ids[1:]]` is the whole evaluation: one fancy index, one `log`, one mean.
- Check for `p <= 0` *before* logging so that an impossible event is a clean `inf` instead of a warning and a NaN-looking pipeline.
- `best_smoothing` reads column 3 (validation). If you pick by column 2 you always choose `k = 0`, the most overfit model.
- Real numbers to remember (on the real data, char level): uniform baseline about 4.5 nats (perplexity ~89 for the 89 characters of the bundled corpus), best smoothed bigram about 2.4 nats on validation (perplexity ~11). Every later model is a way to push that number down.
