"""Lesson 12 - one base model, many adapters. Builds on add_lora and lora_parameters from your lora.py (lesson 08)."""
import torch

from lora import ATTENTION, LoRALinear, add_lora, lora_parameters

MLP = ("fc1", "fc2")


class AdapterBank:
    """A model whose LoRA layers can hold any one of several named adapters.

    __init__(model, targets=ATTENTION + MLP, r=8, alpha=16.0, seed=0): wrap `model` IN PLACE with add_lora (so the
        layers are shared with the caller's model; there is only ever one copy of the base weights) and start with
        no adapter stored and none active.
    names()            the adapter names in the order they were added.
    add(name)          store a fresh adapter: its A matrices random (kaiming uniform, generator seeded with
                       seed + number of adapters already stored), its B matrices zero. ValueError for a name that exists.
    activate(name)     make `name` the adapter the model uses (name=None: no adapter, the model behaves exactly like the
                       plain base; implement it by zeroing every B). FIRST write the live A and B tensors back into the
                       adapter that is active now, so anything trained in place is kept; THEN copy the stored tensors of
                       `name` into the live parameters (copy into them; do not replace the Parameter objects, an optimizer
                       may hold them). ValueError for an unknown name.
    active             property: the active name or None.
    state(name)        {layer name: tensor copy} of an adapter's A and B (sync first if it is the active one).
    remove(name)       forget an adapter (it must not be the active one: ValueError).
    memory_report()    {"base_bytes": 4 * the number of base parameters (the weights that are not A or B), "adapter_bytes":
                       {name: 4 * its number of values}, "separate_models_bytes": number of adapters * base_bytes}.
    """

    def __init__(self, model, targets=ATTENTION + MLP, r=8, alpha=16.0, seed=0):
        # TODO
        raise NotImplementedError

    def names(self):
        # TODO
        raise NotImplementedError

    @property
    def active(self):
        # TODO
        raise NotImplementedError

    def add(self, name):
        # TODO
        raise NotImplementedError

    def activate(self, name):
        # TODO
        raise NotImplementedError

    def state(self, name):
        # TODO
        raise NotImplementedError

    def remove(self, name):
        # TODO
        raise NotImplementedError

    def memory_report(self):
        # TODO
        raise NotImplementedError
