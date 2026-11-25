# Solution notes

- **A strict parser is part of the validator.** `What colour is the lamp` (no question mark) or `what colour is the lamp?`
  do not match a template, so they are dropped. Being lenient here would let malformed rows through whenever the answer
  happens to look right.
- **Exact comparison** is deliberate: `grey ` with a trailing space is a *different training target* (a different token
  sequence), and so is `Grey`. Normalise in the cleaning step (lesson 05) if you want leniency, not in the validator.
- **Same budget, fewer examples, better model.** The validated run sees each remaining example more often and no
  contradicting labels; the noisy run spends a third of its steps on wrong answers. The result holds as long as the dropped rows
  do not remove whole facts; here every fact keeps at least one phrasing.
- **Measure the noise.** `noise_rate` belongs in the data card: a number you can compare between data pulls.
