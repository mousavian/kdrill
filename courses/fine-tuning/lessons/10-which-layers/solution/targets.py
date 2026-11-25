"""Lesson 10 - reference solution."""
import torch.nn as nn

from base import clone
from harness import evaluate_qa
from lora import ATTENTION, add_lora, trainable_count
from masking import train_sft

MLP = ("fc1", "fc2")
GROUPS = {
    "qv": ("query", "value"),
    "attention": ATTENTION,
    "mlp": MLP,
    "attention+mlp": ATTENTION + MLP,
}


def select_targets(group):
    if group not in GROUPS:
        raise ValueError("unknown group %r; choose from %s" % (group, sorted(GROUPS)))
    return GROUPS[group]


def predict_trainable(model, targets, r):
    total = 0
    for _, mod in model.named_modules():
        for cname, child in mod.named_children():
            if isinstance(child, nn.Linear) and cname in targets:
                total += r * (child.in_features + child.out_features)
    return total


def compare_targets(base, tok, items, qa_rows, groups, r=8, alpha=16, steps=250, lr=3e-3, seed=0):
    out = []
    for g in groups:
        targets = select_targets(g)
        pred = predict_trainable(base, targets, r)
        m = clone(base)
        add_lora(m, targets, r, alpha, seed)
        n = trainable_count(m)
        train_sft(m, items, steps, lr, seed=seed)
        q = evaluate_qa(m, tok, qa_rows)
        out.append({"group": g, "trainable": n, "predicted": pred, "format": q["format"], "exact": q["exact"]})
    return out
