"""Lesson 16 - reference solution."""
import math
import re

T95 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262, 10: 2.228,
       12: 2.179, 15: 2.131, 20: 2.086, 30: 2.042}


def words(text):
    return re.findall(r"[a-z0-9']+", text.lower())


def ngrams(text, n):
    w = words(text)
    if not w:
        return set()
    if len(w) < n:
        return {tuple(w)}
    return {tuple(w[i:i + n]) for i in range(len(w) - n + 1)}


def build_index(texts, n):
    idx = set()
    for t in texts:
        idx |= ngrams(t, n)
    return idx


def contaminated(eval_texts, train_texts, n=8):
    idx = build_index(train_texts, n)
    return [bool(ngrams(t, n) & idx) for t in eval_texts]


def overlap_rate(eval_texts, train_texts, n=8):
    idx = build_index(train_texts, n)
    total = hits = 0
    for t in eval_texts:
        w = words(t)
        if not w:
            continue
        grams = [tuple(w)] if len(w) < n else [tuple(w[i:i + n]) for i in range(len(w) - n + 1)]
        total += len(grams)
        hits += sum(1 for g in grams if g in idx)
    return hits / total if total else 0.0


def decontaminate(train_rows, eval_rows, n=8, field="question"):
    idx = build_index([r[field] for r in eval_rows], n)
    kept, removed = [], []
    for r in train_rows:
        (removed if ngrams(r[field], n) & idx else kept).append(r)
    return kept, removed


def mean_std(values):
    n = len(values)
    m = sum(values) / n
    if n < 2:
        return m, 0.0
    return m, math.sqrt(sum((v - m) ** 2 for v in values) / (n - 1))


def ci95(values):
    n = len(values)
    m, s = mean_std(values)
    if n < 2:
        return m, float("inf")
    df = n - 1
    if df > 30:
        t = 1.96
    else:
        t = T95[max(k for k in T95 if k <= df)]
    return m, t * s / math.sqrt(n)


def paired_summary(scores_a, scores_b):
    if len(scores_a) != len(scores_b):
        raise ValueError("the two settings need the same seeds")
    ma, sa = mean_std(scores_a)
    mb, sb = mean_std(scores_b)
    diff, ci = ci95([b - a for a, b in zip(scores_a, scores_b)])
    return {"mean_a": ma, "mean_b": mb, "std_a": sa, "std_b": sb, "diff": diff, "ci": ci, "b_better": diff - ci > 0}


def binomial_se(p, n):
    return math.sqrt(p * (1 - p) / n)
