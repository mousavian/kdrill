"""Lesson 09 - rank and alpha. Builds on add_lora/trainable_count (lesson 08), finetune (02) and text_loss (01)."""
from base import clone
from finetune import finetune
from harness import text_loss
from lora import ATTENTION, add_lora, trainable_count


def lora_run(base, train_ids, val_ids, r, alpha, steps=80, lr=3e-3, targets=ATTENTION, seed=0):
    """One experiment. Work on a COPY of `base` (base.py's clone; the base itself must not change and must not get
    adapters), add_lora(copy, targets, r, alpha, seed), finetune it for `steps` steps at `lr` (warmup=10, seed=seed),
    and return {"r": r, "alpha": alpha, "scale": alpha / r, "trainable": trainable_count(copy),
    "val_loss": text_loss(copy, val_ids)}."""
    # TODO
    raise NotImplementedError


def run_sweep(base, train_ids, val_ids, configs, steps=80, lr=3e-3, targets=ATTENTION):
    """configs is a list of (r, alpha). Return the list of lora_run results in the same order. Every run starts
    from the same untouched base."""
    # TODO
    raise NotImplementedError


def smallest_rank(results, base_loss, full_loss, fraction=0.8):
    """The result (a dict from lora_run) of the cheapest configuration that reaches `fraction` of the gain of full
    fine-tuning: the gain of full fine-tuning is base_loss - full_loss; a result qualifies when
    base_loss - result["val_loss"] >= fraction * (base_loss - full_loss). Among the qualifying results return the one
    with the fewest trainable parameters (ties: the smaller r). Return None when none qualifies."""
    # TODO
    raise NotImplementedError
