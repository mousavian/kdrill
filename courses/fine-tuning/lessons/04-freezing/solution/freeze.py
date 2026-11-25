"""Lesson 04 - reference solution."""
import torch

from finetune import finetune


def freeze_except(model, prefixes):
    prefixes = tuple(prefixes)
    names = [n for n, _ in model.named_parameters()]
    for pre in prefixes:
        if not any(n.startswith(pre) for n in names):
            raise ValueError("no parameter starts with %r" % pre)
    keep = []
    for n, p in model.named_parameters():
        p.requires_grad = n.startswith(prefixes)
        if p.requires_grad:
            keep.append(n)
    return keep


def unfreeze_all(model):
    for p in model.parameters():
        p.requires_grad = True


def param_report(model):
    params = list(model.parameters())          # a shared (tied) parameter is yielded once
    trainable = sum(p.numel() for p in params if p.requires_grad)
    total = sum(p.numel() for p in params)
    return {"trainable": trainable, "total": total, "fraction": trainable / total}


def last_block_prefixes(model):
    return ["blocks.%d." % (len(model.blocks) - 1), "ln_f."]


def train_subset(model, ids, prefixes, steps, lr, **kw):
    freeze_except(model, prefixes)
    report = param_report(model)
    losses = finetune(model, ids, steps, lr, **kw)
    return {"report": report, "losses": losses}
