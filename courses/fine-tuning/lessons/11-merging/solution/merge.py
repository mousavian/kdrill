"""Lesson 11 - reference solution."""
import os

import torch
import torch.nn as nn

from base import clone
from lora import LoRALinear


def merged_weight(layer):
    return layer.base.weight.detach() + layer.scale * (layer.lora_B.detach() @ layer.lora_A.detach())


def merge_lora(model):
    n = 0
    for _, mod in list(model.named_modules()):
        for cname, child in list(mod.named_children()):
            if isinstance(child, LoRALinear):
                lin = nn.Linear(child.base.in_features, child.base.out_features, bias=child.base.bias is not None)
                with torch.no_grad():
                    lin.weight.copy_(merged_weight(child))
                    if child.base.bias is not None:
                        lin.bias.copy_(child.base.bias)
                setattr(mod, cname, lin)
                n += 1
    for p in model.parameters():
        p.requires_grad = True
    return n


def merged_copy(model):
    m = clone(model)
    merge_lora(m)
    return m


@torch.no_grad()
def max_logit_difference(a, b, x):
    wa, wb = a.training, b.training
    a.eval(); b.eval()
    d = float((a(x)[0] - b(x)[0]).abs().max())
    a.train(wa); b.train(wb)
    return d


def save_merged_checkpoint(model, base_checkpoint, out_path, note=""):
    m = model
    if any(isinstance(x, LoRALinear) for x in model.modules()):
        m = merged_copy(model)
    ck = torch.load(base_checkpoint, weights_only=False)
    ck["model_state"] = {k: v.detach().clone() for k, v in m.state_dict().items()}
    ck["merged_from"] = note
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    torch.save(ck, out_path)
    return os.path.getsize(out_path)
