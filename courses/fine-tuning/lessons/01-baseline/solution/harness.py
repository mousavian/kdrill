"""Lesson 01 - reference solution."""
import json
import os

import torch
import torch.nn.functional as F

PROMPT = "Q: {q}\nA:"
EOS = "<|endoftext|>"


@torch.no_grad()
def text_loss(model, ids, window=None):
    if len(ids) < 2:
        raise ValueError("need at least two tokens")
    window = window or model.block_size
    was = model.training
    model.eval()
    total, count = 0.0, 0
    for s in range(0, len(ids) - 1, window):
        x = ids[s:s + window]
        y = ids[s + 1:s + window + 1]
        x = x[:len(y)]
        logits, _ = model(x[None])
        total += float(F.cross_entropy(logits[0], y, reduction="sum"))
        count += len(y)
    model.train(was)
    return total / count


@torch.no_grad()
def complete(model, tok, prompt, max_new_tokens=24):
    eos = tok.special_ids[EOS]
    ids = tok.encode(prompt)
    out = []
    was = model.training
    model.eval()
    finished = False
    for _ in range(max_new_tokens):
        ctx = (ids + out)[-model.block_size:]
        logits, _ = model(torch.tensor([ctx]))
        nxt = int(logits[0, -1].argmax())
        if nxt == eos:
            finished = True
            break
        out.append(nxt)
    model.train(was)
    return tok.decode(out), finished


def format_ok(text, finished):
    return bool(finished and text.startswith(" ") and text.strip() != "" and "\n" not in text)


def exact_match(text, answer):
    return text == " " + answer


def evaluate_qa(model, tok, rows, max_new_tokens=24):
    fmt = exact = 0
    for r in rows:
        text, finished = complete(model, tok, PROMPT.format(q=r["question"]), max_new_tokens)
        ok = format_ok(text, finished)
        fmt += ok
        exact += ok and exact_match(text, r["answer"])
    return {"format": fmt / len(rows), "exact": exact / len(rows), "n": len(rows)}


def evaluate(model, tok, style_ids, orig_ids, qa_rows):
    qa = evaluate_qa(model, tok, qa_rows)
    return {"style_loss": text_loss(model, style_ids), "orig_loss": text_loss(model, orig_ids),
            "format": qa["format"], "exact": qa["exact"], "n_qa": len(qa_rows)}


def write_results(path, results):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, sort_keys=True)
        f.write("\n")


def read_results(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)
