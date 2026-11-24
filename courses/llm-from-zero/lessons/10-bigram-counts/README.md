# 10 - A counting bigram model

## Concept

A **language model** assigns a probability to the next token given what came before. The
simplest one looks only at the *one* previous token: a **bigram** model. You do not train it
with gradient descent; you count. Slide over the training ids, and for every adjacent pair
`(a, b)` add one to `counts[a, b]`. Divide each row by its sum and you have
`P(b | a)`, a table with one probability distribution per row.

That table is already a generative model. Start at some token, draw the next one from its
row, repeat: you get text with the right *local statistics*: `q` is followed by `u`, `th` is
common, spaces fall at plausible places. It is not English (the model has no memory beyond
one character) but it is a real model, and it is the baseline every later model must beat.
In lesson 13 a neural network will learn the *same* table by gradient descent, which is the
best way to see that neural nets are not magic.

Two practical issues show up immediately.

- **Zeros.** A pair never seen in training gets probability 0. Evaluated on new text, one
  zero makes the loss infinite (lesson 11). **Smoothing** adds a small count `k` to every
  cell, trading a little bias for never being shocked. `k = 1` is "add-one" (Laplace).
- **Speed.** Counting a million pairs with a Python `for` loop works but is needlessly slow;
  `np.bincount` on `a * V + b` (or `np.add.at`) does it in a few milliseconds. Habits like
  this matter once you tokenise millions of ids.

Sampling uses a seeded random generator, so a "random" text is reproducible, which you will
want in tests and in bug reports.

## The situation

`bigram.py` has the class with docstrings. `sample_text.py` trains it on your training split
and prints text for two smoothing values. This lesson is **numpy only**: importing PyTorch
here fails verify, because the point is to see everything.

## Your task

Implement `fit`, `probs`, `prob`, `top_next` and `sample`. Verify checks counts on a small
sequence, probabilities and add-k smoothing (including rows of unseen contexts), tie-breaking,
a sampling chain that must follow a deterministic cycle, sample frequencies against the
model's probabilities, speed on a million ids, and a few facts about real English.

Then: `make py F=sample_text.py` and read what a model with one character of memory writes.

## Useful commands

- `kdrill py`, `kdrill hint`, `kdrill solution`.
- `np.set_printoptions(precision=2, suppress=True)` makes small matrices readable.

## On a real project

n-gram models with smoothing (Kneser-Ney) powered speech recognition and translation for
decades and are still used as cheap baselines and for data filtering.

## Read more

- Speech and Language Processing, ch. 3 (N-gram language models): https://web.stanford.edu/~jurafsky/slp3/3.pdf
- NumPy `bincount`: https://numpy.org/doc/stable/reference/generated/numpy.bincount.html
- NumPy random Generator: https://numpy.org/doc/stable/reference/random/generator.html
