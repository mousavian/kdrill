"""Lesson 05 - reference solution."""
import random

import torch

EOS = "<|endoftext|>"


def clean_text(s):
    return " ".join(s.split())


def format_example(question, answer):
    return "Q: " + question + "\nA:", " " + answer + EOS


def clean_examples(rows, max_words=20):
    seen, out = set(), []
    for r in rows:
        q, a = r.get("question", ""), r.get("answer", "")
        if EOS in a or "\n" in a or "\n" in q:
            continue
        q, a = clean_text(q), clean_text(a)
        if not q or not a:
            continue
        if len(q.split()) + len(a.split()) > max_words:
            continue
        if q in seen:
            continue
        seen.add(q)
        out.append({"question": q, "answer": a})
    return out


def split_examples(examples, eval_fraction=0.2, seed=0):
    if not 0 < eval_fraction < 1:
        raise ValueError("eval_fraction must be between 0 and 1")
    qs = [e["question"] for e in examples]
    if len(set(qs)) != len(qs):
        raise ValueError("duplicate questions: deduplicate before splitting")
    n_eval = max(1, round(len(examples) * eval_fraction))
    idx = list(range(len(examples)))
    random.Random(seed).shuffle(idx)
    ev = set(idx[:n_eval])
    return [e for i, e in enumerate(examples) if i not in ev], [e for i, e in enumerate(examples) if i in ev]


def encode_example(tok, question, answer):
    prompt, completion = format_example(question, answer)
    p = tok.encode(prompt)
    return p + tok.encode(completion), len(p)


def encode_all(tok, examples, block_size):
    items, dropped = [], 0
    for e in examples:
        ids, pl = encode_example(tok, e["question"], e["answer"])
        if len(ids) > block_size:
            dropped += 1
        else:
            items.append((ids, pl))
    return items, dropped


def dataset_stats(items):
    total = sum(len(i) for i, _ in items)
    ans = sum(len(i) - p for i, p in items)
    return {"n": len(items), "mean_len": total / len(items), "max_len": max(len(i) for i, _ in items), "answer_share": ans / total}
