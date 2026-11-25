"""Lesson 17 - reference solution."""
import json
import os

import torch

from base import clone, load_base
from harness import evaluate_qa, text_loss
from lora import ATTENTION, add_lora, save_adapter, trainable_count
from masking import train_sft
from sft_data import clean_examples, encode_all
from trust import decontaminate, mean_std

MLP = ("fc1", "fc2")
DEFAULTS = dict(method="lora", steps=150, lr=3e-3, r=8, alpha=16.0, targets=ATTENTION + MLP, batch_size=16,
                seeds=[0], base_path="base/checkpoint.pt", orig_text="data/holmes_val.txt", orig_tokens=3000)


def _orig_loss(model, tok, cfg):
    if not os.path.exists(cfg["orig_text"]):
        return None
    with open(cfg["orig_text"], encoding="utf-8") as f:
        ids = torch.tensor(tok.encode(f.read()), dtype=torch.long)[:cfg["orig_tokens"]]
    return text_loss(model, ids)


def run_capstone(train_rows, eval_rows, out_dir, config=None, limitations=""):
    cfg = dict(DEFAULTS)
    cfg.update(config or {})
    if cfg["method"] not in ("lora", "full"):
        raise ValueError("method must be 'lora' or 'full'")
    base, tok = load_base(cfg["base_path"])
    train = clean_examples(train_rows)
    if not train:
        raise ValueError("no training examples left after cleaning")
    train, removed = decontaminate(train, eval_rows, n=8, field="question")
    items, too_long = encode_all(tok, train, base.block_size)
    b = evaluate_qa(base, tok, eval_rows)
    base_res = {"format": b["format"], "exact": b["exact"], "orig_loss": _orig_loss(base, tok, cfg)}
    os.makedirs(out_dir, exist_ok=True)
    runs, trainable = [], None
    for k, seed in enumerate(cfg["seeds"]):
        m = clone(base)
        if cfg["method"] == "lora":
            add_lora(m, cfg["targets"], cfg["r"], cfg["alpha"], seed)
            trainable = trainable_count(m)
        else:
            trainable = sum(p.numel() for p in m.parameters())
        train_sft(m, items, cfg["steps"], cfg["lr"], batch_size=cfg["batch_size"], seed=seed)
        q = evaluate_qa(m, tok, eval_rows)
        runs.append({"format": q["format"], "exact": q["exact"], "orig_loss": _orig_loss(m, tok, cfg)})
        if k == 0:
            if cfg["method"] == "lora":
                save_adapter(m, os.path.join(out_dir, "adapter.pt"))
            else:
                ck = torch.load(cfg["base_path"], weights_only=False)
                ck["model_state"] = m.state_dict()
                torch.save(ck, os.path.join(out_dir, "tuned.pt"))
    mean = lambda key: (sum(r[key] for r in runs) / len(runs)) if runs[0][key] is not None else None
    exacts = [r["exact"] for r in runs]
    results = {"method": cfg["method"], "n_train": len(items), "n_eval": len(eval_rows), "n_removed": len(removed),
               "n_too_long": too_long, "trainable": trainable,
               "config": dict(cfg, targets=list(cfg["targets"]), seeds=list(cfg["seeds"])),
               "base": base_res, "tuned": {"format": mean("format"), "exact": mean("exact"), "orig_loss": mean("orig_loss")},
               "exact_per_seed": exacts, "exact_std": mean_std(exacts)[1]}
    with open(os.path.join(out_dir, "results.json"), "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, sort_keys=True)
        f.write("\n")
    source = ""
    sp = os.path.join(os.path.dirname(cfg["base_path"]), "SOURCE.txt")
    if os.path.exists(sp):
        with open(sp, encoding="utf-8") as f:
            source = f.read()
    with open(os.path.join(out_dir, "MODEL_CARD.md"), "w", encoding="utf-8") as f:
        f.write(make_model_card(results, source, limitations))
    return results


def make_model_card(results, source, limitations):
    r, c = results, results["config"]
    f3 = lambda x: "n/a" if x is None else "%.3f" % x
    method = ["- method: %s" % r["method"], "- steps: %d, learning rate: %g, batch size: %d" % (c["steps"], c["lr"], c["batch_size"]),
              "- seeds: %s" % ", ".join(str(s) for s in c["seeds"])]
    if r["method"] == "lora":
        method += ["- rank %d, alpha %g, adapted layers: %s" % (c["r"], c["alpha"], ", ".join(c["targets"])),
                   "- trainable parameters: %d" % r["trainable"]]
    else:
        method += ["- every weight trained: %d parameters" % r["trainable"]]
    lines = ["# Model card", "",
             "## Task", "", "A question-answer task learned from %d training examples and measured on %d held-out questions." % (r["n_train"], r["n_eval"]), "",
             "## Base model", "", source.strip(), "",
             "## Data", "", "- training examples used: %d" % r["n_train"], "- removed as contaminated (shared a question with the evaluation set): %d" % r["n_removed"],
             "- dropped as too long for the context: %d" % r["n_too_long"], "- held-out evaluation questions: %d" % r["n_eval"], "",
             "## Method", ""] + method + [
             "", "## Results", "", "| | format | exact match | original-text loss |", "|---|---|---|---|",
             "| base | %s | %s | %s |" % (f3(r["base"]["format"]), f3(r["base"]["exact"]), f3(r["base"]["orig_loss"])),
             "| tuned | %s | %s | %s |" % (f3(r["tuned"]["format"]), f3(r["tuned"]["exact"]), f3(r["tuned"]["orig_loss"])), "",
             "Exact match per seed: %s (standard deviation %s)." % (", ".join(f3(x) for x in r["exact_per_seed"]), f3(r["exact_std"])), "",
             "## Limitations", "", limitations.strip(), ""]
    return "\n".join(lines)
