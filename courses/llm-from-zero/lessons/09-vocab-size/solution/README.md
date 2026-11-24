# Solution notes

- `study` trains once. The nested-merges property (the first k merges of a deterministic BPE equal the tokenizer trained with k merges) turns a minutes-long sweep into one training run plus cheap slicing.
- The reference choice (600) comes from this table on the real data: tokens per word is still falling steeply up to ~600 (5.1, 3.7, 2.9, 2.4), then flattens (2.0, 1.8, 1.7), while the share of rarely used merges explodes after ~600 (4 percent, 28 percent, 55 percent, 69 percent). Your numbers will differ with different data and thresholds; a different choice with a clear argument is fine.
- Note what the rare fraction would do with a corpus ten times bigger: the same sizes would all look healthier. The right vocabulary depends on the amount of data, not only on the language.
