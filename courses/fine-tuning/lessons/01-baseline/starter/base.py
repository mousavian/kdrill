"""Loads the base model (finished; you do not edit it).

base/checkpoint.pt is your llm-from-zero capstone model when it fits this course, else the reference base
model that ships with the course; base/SOURCE.txt says which. The classes come from kdlib.refmodel: the GPT
and BPE of llm-from-zero (the reference solutions, same parameter names, so your checkpoint loads).
"""
import copy

import torch

from kdlib.refmodel import BPE, GPT

EOS = "<|endoftext|>"


def load_base(path="base/checkpoint.pt"):
    """Return (model, tokenizer): the GPT in eval mode and its BPE."""
    ck = torch.load(path, weights_only=False, map_location="cpu")
    model = GPT(**ck["gpt_config"])
    model.load_state_dict(ck["model_state"])
    model.eval()
    return model, BPE.from_dict(ck["tokenizer"])


def encode(tok, text):
    """Text to a 1-D LongTensor of token ids."""
    return torch.tensor(tok.encode(text), dtype=torch.long)


def read_text(name):
    """data/<name>.txt as one string, e.g. read_text('alice_val')."""
    with open("data/%s.txt" % name, encoding="utf-8") as f:
        return f.read()


def clone(model):
    """An independent copy of a model (weights and all). The attention heads keep their last attention matrix in
    `head.att`; if it was computed with gradients it is not copyable, so it is dropped first."""
    for mod in model.modules():
        if hasattr(mod, "att"):
            mod.att = None
    return copy.deepcopy(model)
