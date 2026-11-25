"""Lesson 11 - merging adapters into the weights. Builds on LoRALinear from your lora.py (lesson 08)."""
import os

import torch
import torch.nn as nn

from base import clone
from lora import LoRALinear


def merged_weight(layer):
    """The weight matrix (out, in) of a LoRALinear with its adapter folded in:
    base.weight + layer.scale * (layer.lora_B @ layer.lora_A). A new tensor; the layer is not modified."""
    # TODO
    raise NotImplementedError


def merge_lora(model):
    """Replace, in place, every LoRALinear of `model` by an ordinary nn.Linear with the merged weight and a copy of
    the base bias (or no bias when the base had none). Afterwards EVERY parameter of the model requires gradients again (it is an ordinary model, not a frozen
    base with adapters). Return the number of
    layers merged (0 for a model without adapters). Afterwards the model has exactly the parameter names and shapes of the
    original GPT, so state_dict() of the merged model loads into a plain GPT."""
    # TODO
    raise NotImplementedError


def merged_copy(model):
    """A merged copy (clone, then merge_lora on the copy); `model` keeps its adapters and its behaviour."""
    # TODO
    raise NotImplementedError


def max_logit_difference(a, b, x):
    """Largest absolute difference between the logits of two models on the token batch x (no gradients, eval mode
    for both during the call, previous modes restored). A float."""
    # TODO
    raise NotImplementedError


def save_merged_checkpoint(model, base_checkpoint, out_path, note=""):
    """Write the merged `model` as a checkpoint in the format of base/checkpoint.pt: load the base checkpoint dict, replace
    "model_state" by model.state_dict() (merge first if the model still has adapters: do not modify `model`), set "merged_from"
    to the string `note`, torch.save to out_path (create the folder). Return the size of the file in bytes."""
    # TODO
    raise NotImplementedError
