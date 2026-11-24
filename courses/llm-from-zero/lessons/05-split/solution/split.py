"""Lesson 05 - reference solution."""
import json
import os
import random
import re


def split_documents(docs, fractions=(0.8, 0.1, 0.1), seed=0):
    names_of = ("train", "val", "test")
    if abs(sum(fractions) - 1.0) > 1e-6:
        raise ValueError("fractions must sum to 1")
    active = [i for i, f in enumerate(fractions) if f > 0]
    if len(docs) < len(active):
        raise ValueError("need at least %d documents" % len(active))
    names = sorted(docs)
    random.Random(seed).shuffle(names)
    total = sum(len(docs[n]) for n in names)
    got = [0.0, 0.0, 0.0]
    out = {k: [] for k in names_of}
    for pos, n in enumerate(names):
        empty = [i for i in active if not out[names_of[i]]]
        left = len(names) - pos
        if empty and left <= len(empty):
            i = max(empty, key=lambda j: fractions[j] * total - got[j])   # must feed an empty split now
        else:
            i = max(active, key=lambda j: fractions[j] * total - got[j])
        out[names_of[i]].append(n)
        got[i] += len(docs[n])
    return {k: sorted(v) for k, v in out.items()}


def split_lines_randomly(lines, val_frac=0.1, seed=0):
    idx = list(range(len(lines)))
    random.Random(seed).shuffle(idx)
    val_idx = set(idx[:round(len(lines) * val_frac)])
    return ([l for i, l in enumerate(lines) if i not in val_idx], [l for i, l in enumerate(lines) if i in val_idx])


def words(text):
    return re.findall(r"[a-z0-9']+", text.lower())


def _grams(text, n):
    w = words(text)
    return [tuple(w[i:i + n]) for i in range(len(w) - n + 1)]


def ngram_overlap(reference_text, other_text, n=8):
    other = _grams(other_text, n)
    if not other:
        return 0.0
    ref = set(_grams(reference_text, n))
    return sum(g in ref for g in other) / len(other)


def oov_rate(train_text, other_text):
    other = words(other_text)
    if not other:
        return 0.0
    vocab = set(words(train_text))
    return sum(w not in vocab for w in other) / len(other)


def write_splits(docs, assignment, outdir):
    os.makedirs(outdir, exist_ok=True)
    sizes = {}
    for split in ("train", "val", "test"):
        text = "\n\n".join(docs[n].strip() for n in sorted(assignment[split])) + "\n"
        with open(os.path.join(outdir, split + ".txt"), "w", encoding="utf-8") as f:
            f.write(text)
        sizes[split] = len(text)
    with open(os.path.join(outdir, "splits.json"), "w", encoding="utf-8") as f:
        json.dump(assignment, f, indent=2)
    return sizes
