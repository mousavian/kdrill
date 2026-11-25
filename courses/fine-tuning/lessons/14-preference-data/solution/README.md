# Solution notes

- **Validity is a conjunction of cheap rules**, each one aimed at a real failure: empty fields, identical pairs, swapped labels, answers that
  are not comparable. Running them on the raw row (before stripping) keeps "empty after strip" from being hidden.
- **Leakage list**: the evaluation prompts are an argument, so the same function cleans training data for any evaluation set.
- **`completion_logprobs` is the loss of lesson 06 with the sign flipped and no division**: the same mask (targets that belong to the completion),
  summed per sequence instead of averaged over the batch.
- **Why longer answers score lower**: every extra token multiplies in another probability below 1, so the summed log-probability falls with
  length. Comparing raw sums between a short and a long answer mostly measures length. DPO avoids that by comparing *changes* relative to a
  reference model, which is the next lesson.
- **Padding invariance** holds because causal attention never lets a real token see the right padding, and the mask removes the padded targets.
