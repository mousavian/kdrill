# Solution notes

- **Order of operations matters**: check the raw strings for the marker and newlines *before* cleaning (cleaning turns a
  newline into a space and hides the problem), clean *before* looking for duplicates (spacing variants are duplicates),
  deduplicate *before* splitting.
- **`split_examples` refuses duplicates** instead of fixing them: a function that silently deduplicates hides the fact
  that the caller skipped a step, and the leak comes back the first time someone reorders the pipeline.
- **Rounding**: `round(len * fraction)` and at least one eval example, so tiny datasets still have an evaluation set.
- **The tokenization boundary** is checked by encoding the whole string and comparing; the test does that for a sample of
  questions. With a tokenizer whose pieces can cross the colon the two would differ and you would train on tokens the
  model never produces at inference.
- **`answer_share`** is the number to remember for lesson 06: most of the loss in a naive run is spent on predicting the
  question again.
