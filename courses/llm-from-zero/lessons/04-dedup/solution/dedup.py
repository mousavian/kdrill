"""Lesson 04 - reference solution."""
import hashlib
import re
from collections import defaultdict


def paragraphs(text):
    return [p.strip() for p in re.split(r"\n[ \t]*\n", text) if p.strip()]


def norm_key(par):
    return "".join(c for c in par.lower() if c.isalnum())


def exact_dedup(paras):
    seen, kept = set(), []
    for p in paras:
        h = hashlib.blake2b(norm_key(p).encode("utf-8"), digest_size=16).digest()
        if h in seen:
            continue
        seen.add(h)
        kept.append(p)
    return kept, len(paras) - len(kept)


def shingles(par, k=5):
    words = re.findall(r"\w+", par.lower())
    if not words:
        return set()
    if len(words) < k:
        return {" ".join(words)}
    return {" ".join(words[i:i + k]) for i in range(len(words) - k + 1)}


def jaccard(a, b):
    union = len(a | b)
    return len(a & b) / union if union else 0.0


def near_dedup(paras, threshold=0.8, k=5):
    kept, dropped = [], []
    kept_sets = []            # shingle set of each kept paragraph
    kept_orig = []            # original index of each kept paragraph
    index = defaultdict(list)  # shingle -> positions in `kept`
    for i, p in enumerate(paras):
        sh = shingles(p, k)
        cand = set()
        for s in sh:
            cand.update(index[s])
        best, best_sim = None, -1.0
        for c in sorted(cand):
            sim = jaccard(sh, kept_sets[c])
            if sim > best_sim:
                best, best_sim = c, sim
        if best is not None and best_sim >= threshold:
            dropped.append((i, kept_orig[best], best_sim))
            continue
        pos = len(kept)
        kept.append(p)
        kept_sets.append(sh)
        kept_orig.append(i)
        for s in sh:
            index[s].append(pos)
    return kept, dropped


def junk_reason(par, min_chars=15, min_alpha=0.6):
    if len(par) < min_chars:
        return "too_short"
    if sum(c.isalpha() for c in par) / len(par) < min_alpha:
        return "low_alpha"
    return None


def filter_and_dedup(paras, min_chars=15, min_alpha=0.6, threshold=0.8, k=5):
    stats = {"input": len(paras), "too_short": 0, "low_alpha": 0}
    survivors = []
    for p in paras:
        r = junk_reason(p, min_chars, min_alpha)
        if r:
            stats[r] += 1
        else:
            survivors.append(p)
    survivors, n_exact = exact_dedup(survivors)
    survivors, dropped = near_dedup(survivors, threshold, k)
    stats.update(exact_duplicates=n_exact, near_duplicates=len(dropped), kept=len(survivors))
    return survivors, stats
