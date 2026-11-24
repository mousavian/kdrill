"""Lesson 05 - split without leakage.

Fill in the TODOs. See the effect on the real corpus:  make py F=leakage_demo.py
"""
import json
import os
import random
import re


def split_documents(docs, fractions=(0.8, 0.1, 0.1), seed=0):
    """Assign whole documents to "train", "val" and "test".

    `docs` is a dict name -> text. `fractions` are the target shares of CHARACTERS
    for train, val, test. Return {"train": [names], "val": [names], "test": [names]}
    with every list sorted by name. Rules:
    - a partition: every document in exactly one split
    - deterministic for a seed, and independent of the dict's insertion order
      (sort the names before shuffling them with random.Random(seed))
    - every split with a fraction > 0 gets at least one document
    - shares of characters follow the fractions as well as whole documents allow
      (a greedy idea: give the next document to the split furthest below its target)
    - raise ValueError if fractions do not sum to 1 (tolerance 1e-6), or if there are
      fewer documents than splits with a fraction > 0
    """
    # TODO
    raise NotImplementedError


def split_lines_randomly(lines, val_frac=0.1, seed=0):
    """The WRONG way, for comparison: shuffle the lines (random.Random(seed)) and put
    the first round(len(lines) * val_frac) into validation, the rest into training.
    Return (train_lines, val_lines); both keep the original relative order."""
    # TODO
    raise NotImplementedError


def words(text):
    """Lower-case words: re.findall(r"[a-z0-9']+", text.lower())"""
    return re.findall(r"[a-z0-9']+", text.lower())


def ngram_overlap(reference_text, other_text, n=8):
    """Share of the word n-grams of `other_text` that also occur in `reference_text`
    (n-grams of consecutive `words`). 0.0 when other_text has no n-gram."""
    # TODO
    raise NotImplementedError


def oov_rate(train_text, other_text):
    """Share of the word tokens of `other_text` whose word never occurs in
    `train_text` (out-of-vocabulary rate). 0.0 for an empty other_text."""
    # TODO
    raise NotImplementedError


def write_splits(docs, assignment, outdir):
    """Write outdir/train.txt, val.txt, test.txt and outdir/splits.json.

    Each text file holds the documents of its split in sorted name order, every
    document stripped, joined by a blank line, and ends with a single newline.
    splits.json is `assignment` (name lists per split) as JSON.
    Create outdir if needed. Return {"train": n_chars, "val": n_chars, "test": n_chars}
    (characters in the written files)."""
    # TODO
    raise NotImplementedError
