"""Lesson 08 - LoRA by hand. Not allowed: peft, trl, transformers, torch.nn.utils.parametrize."""
import math
import os

import torch
import torch.nn as nn

ATTENTION = ("key", "query", "value", "proj")


class LoRALinear(nn.Module):
    """y = base(x) + (alpha / r) * (x @ A^T) @ B^T   with   A: (r, in_features), B: (out_features, r).

    - `base` is the nn.Linear to wrap; keep THE SAME object as self.base (no copy) and freeze its parameters
      (requires_grad False).
    - lora_A is an nn.Parameter initialised like nn.Linear's weight: nn.init.kaiming_uniform_(A, a=math.sqrt(5),
      generator=generator); lora_B is an nn.Parameter of zeros, so that at the start the layer computes exactly base(x).
    - self.r, self.alpha and self.scale = alpha / r are plain attributes."""

    def __init__(self, base, r, alpha, generator=None):
        super().__init__()
        # TODO
        raise NotImplementedError

    def forward(self, x):
        # TODO
        raise NotImplementedError


def add_lora(model, targets=ATTENTION, r=8, alpha=16.0, seed=0):
    """Freeze every parameter of `model`, then wrap in place every nn.Linear that is a DIRECT child whose attribute
    name (the last part of its module name, e.g. 'key' in 'blocks.0.attn.heads.1.key') is in `targets`, with
    LoRALinear(linear, r, alpha, generator) where generator = torch.Generator().manual_seed(seed) is shared by all.
    Do not look inside a LoRALinear (its own 'base' is not a target). Return the list of wrapped module names
    (dotted paths, in the order model.named_modules() visits their parents). Raise ValueError when nothing was wrapped (a typo in targets, or the model
    already has adapters on those layers)."""
    # TODO
    raise NotImplementedError


def lora_parameters(model):
    """List of (name, parameter) for every lora_A and lora_B, names like 'blocks.0.attn.proj.lora_A'."""
    # TODO
    raise NotImplementedError


def trainable_count(model):
    """Number of scalar parameters with requires_grad=True (a shared parameter once)."""
    # TODO
    raise NotImplementedError


def save_adapter(model, path):
    """Write ONLY the adapter to `path` with torch.save of {"r": r, "alpha": alpha, "state": {name: tensor}} (state:
    the lora_A / lora_B tensors by the names of lora_parameters, detached copies). Create the folder.
    Return the size of the file in bytes."""
    # TODO
    raise NotImplementedError


def load_adapter(model, path):
    """Load a file made by save_adapter into a model that was prepared with add_lora (same targets). Raise
    ValueError when the names or the shapes do not match the model (for example another rank). Also set alpha
    and scale of every LoRALinear from the file."""
    # TODO
    raise NotImplementedError
