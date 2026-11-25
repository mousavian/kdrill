"""Lesson 04 - freezing: train a chosen part of the model. Builds on finetune() from your finetune.py."""
import torch

from finetune import finetune


def freeze_except(model, prefixes):
    """Make exactly the parameters whose name (from model.named_parameters()) starts with one of `prefixes`
    trainable (requires_grad=True) and freeze all the others (requires_grad=False). Return the list of the
    trainable names in the model's own order. Raise ValueError when a prefix matches no parameter (a typo
    would otherwise silently freeze everything). Names look like 'blocks.2.ffn.fc1.weight', 'ln_f.bias'."""
    # TODO
    raise NotImplementedError


def unfreeze_all(model):
    """Every parameter trainable again."""
    # TODO
    raise NotImplementedError


def param_report(model):
    """{"trainable": parameters with requires_grad, "total": all parameters, "fraction": trainable / total}.
    A parameter shared by two modules (the tied embedding and output layer) is counted once."""
    # TODO
    raise NotImplementedError


def last_block_prefixes(model):
    """The prefixes of the last transformer block and the final layer norm, e.g. ['blocks.2.', 'ln_f.'] for
    a model with three blocks (use len(model.blocks))."""
    # TODO
    raise NotImplementedError


def train_subset(model, ids, prefixes, steps, lr, **kw):
    """Freeze everything except `prefixes`, fine-tune with your finetune() (extra keyword arguments such as
    batch_size or seed go to it) and return {"report": param_report(model), "losses": the loss list}."""
    # TODO
    raise NotImplementedError
