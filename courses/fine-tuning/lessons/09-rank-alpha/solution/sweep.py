"""Lesson 09 - reference solution."""
from base import clone
from finetune import finetune
from harness import text_loss
from lora import ATTENTION, add_lora, trainable_count


def lora_run(base, train_ids, val_ids, r, alpha, steps=80, lr=3e-3, targets=ATTENTION, seed=0):
    m = clone(base)
    add_lora(m, targets, r, alpha, seed)
    finetune(m, train_ids, steps=steps, lr=lr, warmup=10, seed=seed)
    return {"r": r, "alpha": alpha, "scale": alpha / r, "trainable": trainable_count(m), "val_loss": text_loss(m, val_ids)}


def run_sweep(base, train_ids, val_ids, configs, steps=80, lr=3e-3, targets=ATTENTION):
    return [lora_run(base, train_ids, val_ids, r, a, steps, lr, targets) for r, a in configs]


def smallest_rank(results, base_loss, full_loss, fraction=0.8):
    need = fraction * (base_loss - full_loss)
    ok = [x for x in results if base_loss - x["val_loss"] >= need]
    if not ok:
        return None
    return min(ok, key=lambda x: (x["trainable"], x["r"]))
