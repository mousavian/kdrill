`lora_run`: `m = clone(base)` (from `base.py`; plain `copy.deepcopy` can fail after a forward pass with gradients), `add_lora(m, targets, r, alpha, seed)`, `finetune(m, train_ids, steps=steps, lr=lr, warmup=10, seed=seed)`, then build the result dict with `alpha / r` for `scale`, `trainable_count(m)` and `text_loss(m, val_ids)`. Never call `add_lora` on `base` itself.
---
`run_sweep` is a list comprehension over the configs calling `lora_run` with the same base each time (so the order cannot matter). Pass `steps`, `lr` and `targets` through.
---
`smallest_rank`: `need = fraction * (base_loss - full_loss)`; keep results where `base_loss - r["val_loss"] >= need`; return `None` if the list is empty, else `min(ok, key=lambda x: (x["trainable"], x["r"]))`. That key handles ties by rank.
