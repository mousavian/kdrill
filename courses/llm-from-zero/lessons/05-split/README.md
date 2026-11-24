# 05 - Split without leakage

## Concept

A model is judged on text it has not trained on. If that text is not truly unseen, the
score is a lie, and you will tune, ship and trust a model that is worse than it looks.
**Leakage** is any path by which information about the validation or test set reaches
training.

The classic mistake with text is to shuffle lines (or fixed-size windows) and cut 90/10.
Adjacent lines of the same story share characters, names, places and phrases; a line from
the validation set has its neighbours, its topic and often a near-copy sitting in the
training set. Validation loss then rewards memorisation instead of generalisation. The
fix is to split at the level of the **unit that should be independent**: here the whole
document (a book, a story). Then validation measures "text from a story the model never
saw", which is what you actually care about.

Two quick measurements make the problem visible. The **out-of-vocabulary rate** is the
share of validation words that never appear in training: with a line split, character
names are all covered; with a document split, a new story brings new names. The
**n-gram overlap** is the share of validation word 8-grams that also occur in training:
high overlap means shared passages. Compute both whenever you build a split.

Practical rules: split *before* any step that looks at the data statistically (building a
tokenizer vocabulary, choosing thresholds), keep the test set untouched until the very end,
make the split deterministic (a seed, sorted names) and write down which document went
where. With only nine books, "every split must contain at least one document" is a real
constraint, not a footnote.

## The situation

`split.py` holds the interface. `leakage_demo.py` splits the real corpus both ways and
prints the two measurements side by side.

## Your task

Implement `split_documents`, `split_lines_randomly` (the wrong way, kept so you can compare),
`ngram_overlap`, `oov_rate` and `write_splits`. Verify checks the partition, determinism
(also against the order of the input dict), character shares for many documents, non-empty
splits for very few, the error cases, exact values for the two measurements, a synthetic
corpus where the line split demonstrably flatters validation, and the exact file format.

Then run `make py F=leakage_demo.py` and look at the numbers.

## Useful commands

- `kdrill py`, then `import split`.
- `kdrill hint`, `kdrill reset`, `kdrill solution`.

## On a real project

Split by author, by time (train on the past, test on the future), or by source site; and
deduplicate across splits. For benchmarks, check whether test items appear in the training
data at all ("contamination", lesson 25).

## Read more

- Google's ML Crash Course, data splits and leakage: https://developers.google.com/machine-learning/crash-course/overfitting/dividing-datasets
- scikit-learn, common pitfalls (data leakage): https://scikit-learn.org/stable/common_pitfalls.html
