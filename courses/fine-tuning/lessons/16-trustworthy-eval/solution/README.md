# Solution notes

- **Short texts are their own n-gram**: with questions of six words an 8-gram check would never fire; treating a text shorter than `n` as
  a single gram makes exact repeats detectable without a second function.
- **Count occurrences for the rate, use sets for the flag**: a repeated sentence in the eval text is repeated contamination; flags only need
  to know whether anything matched.
- **Normalise before comparing**: lower-casing and keeping only alphanumerics means a copied sentence with different punctuation or case is still caught.
- **Paired differences**: with the same seeds for both settings, `b - a` per seed removes the variation they share; a steady +0.02 is significant even
  when the seeds spread 0.15, and a mean gain of +0.03 with swings of 0.2 is not.
- **Few seeds need the t table**: 4 seeds give a multiplier of 3.18, so an interval from 4 runs is much wider than a normal approximation suggests.
- **Test-set noise is separate from seed noise**: `binomial_se` shows why 100 evaluation questions cannot resolve a 3-point difference.
