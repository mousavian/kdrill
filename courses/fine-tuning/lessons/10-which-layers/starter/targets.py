"""Lesson 10 - where to put the adapters. Builds on lora.py (08), masking.train_sft (06), harness.evaluate_qa (01)."""
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
    """The tuple of layer names of a group in GROUPS ('attention' -> ('key', 'query', 'value', 'proj')).
    Raise ValueError for an unknown group name."""
    # TODO
    raise NotImplementedError


def predict_trainable(model, targets, r):
    """The number of trainable parameters add_lora(model, targets, r) WOULD create, computed without changing the
    model: the sum of r * (in_features + out_features) over every nn.Linear that is a direct child of a module under
    an attribute name in `targets` (walk model.named_modules() and each module's named_children())."""
    # TODO
    raise NotImplementedError


def compare_targets(base, tok, items, qa_rows, groups, r=8, alpha=16, steps=250, lr=3e-3, seed=0):
    """For every group name in `groups`: copy the base (clone), add_lora with that group's targets, train with your
    train_sft(copy, items, steps, lr, seed=seed) on the question-answer items, evaluate with evaluate_qa on qa_rows.
    Return a list of {"group", "trainable", "predicted", "format", "exact"} in the order of `groups`, where
    "predicted" is predict_trainable on the untouched base and "trainable" the real count after add_lora."""
    # TODO
    raise NotImplementedError
