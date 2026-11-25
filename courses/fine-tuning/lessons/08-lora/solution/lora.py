"""Lesson 08 - reference solution."""
import math
import os

import torch
import torch.nn as nn

ATTENTION = ("key", "query", "value", "proj")


class LoRALinear(nn.Module):
    def __init__(self, base, r, alpha, generator=None):
        super().__init__()
        self.base = base
        for p in base.parameters():
            p.requires_grad = False
        self.r, self.alpha = r, alpha
        self.scale = alpha / r
        self.lora_A = nn.Parameter(torch.empty(r, base.in_features))
        nn.init.kaiming_uniform_(self.lora_A, a=math.sqrt(5), generator=generator)
        self.lora_B = nn.Parameter(torch.zeros(base.out_features, r))

    def forward(self, x):
        return self.base(x) + self.scale * ((x @ self.lora_A.T) @ self.lora_B.T)


def add_lora(model, targets=ATTENTION, r=8, alpha=16.0, seed=0):
    for p in model.parameters():
        p.requires_grad = False
    g = torch.Generator().manual_seed(seed)
    names = []
    for name, mod in list(model.named_modules()):
        if isinstance(mod, LoRALinear):
            continue
        for cname, child in list(mod.named_children()):
            if isinstance(child, nn.Linear) and cname in targets and not isinstance(mod, LoRALinear):
                setattr(mod, cname, LoRALinear(child, r, alpha, g))
                names.append((name + "." if name else "") + cname)
    if not names:
        raise ValueError("no layer matched %r (or they already have adapters)" % (targets,))
    return names


def lora_parameters(model):
    return [(n, p) for n, p in model.named_parameters() if n.endswith("lora_A") or n.endswith("lora_B")]


def trainable_count(model):
    return sum(p.numel() for p in model.parameters() if p.requires_grad)


def save_adapter(model, path):
    mods = [m for m in model.modules() if isinstance(m, LoRALinear)]
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    torch.save({"r": mods[0].r, "alpha": mods[0].alpha,
                "state": {n: p.detach().clone() for n, p in lora_parameters(model)}}, path)
    return os.path.getsize(path)


def load_adapter(model, path):
    ck = torch.load(path, weights_only=False)
    mine = dict(lora_parameters(model))
    if set(mine) != set(ck["state"]):
        raise ValueError("the adapter's layers do not match the model's")
    for n, p in mine.items():
        if tuple(p.shape) != tuple(ck["state"][n].shape):
            raise ValueError("shape mismatch for %s: %s vs %s" % (n, tuple(p.shape), tuple(ck["state"][n].shape)))
    with torch.no_grad():
        for n, p in mine.items():
            p.copy_(ck["state"][n])
    for m in model.modules():
        if isinstance(m, LoRALinear):
            m.alpha, m.scale = ck["alpha"], ck["alpha"] / m.r
