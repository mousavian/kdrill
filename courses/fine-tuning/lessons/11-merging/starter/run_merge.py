"""Train an adapter, merge it, compare.   make py F=run_merge.py   (about 15 s)"""
import os

import torch

from base import clone, encode, load_base, read_text
from finetune import finetune
from harness import text_loss, write_results
from lora import add_lora, save_adapter
from merge import max_logit_difference, merge_lora, merged_copy, save_merged_checkpoint

base, tok = load_base()
train = encode(tok, read_text("alice_train"))
val = encode(tok, read_text("alice_val"))
m = clone(base)
add_lora(m, r=8, alpha=16)
finetune(m, train, steps=100, lr=3e-3, warmup=10)
merged = merged_copy(m)
x = val[:128].reshape(2, 64)
print("style loss: base %.4f, with adapter %.4f, merged %.4f" % (text_loss(base, val), text_loss(m, val), text_loss(merged, val)))
print("largest logit difference adapter vs merged: %.2e" % max_logit_difference(m, merged, x))
a = save_adapter(m, "adapters/merged_demo.pt")
b = save_merged_checkpoint(m, "base/checkpoint.pt", "models/style_merged.pt", note="lora r=8 alpha=16 on alice")
print("adapter file %d bytes; merged checkpoint %d bytes (= a whole model); base checkpoint %d bytes" % (a, b, os.path.getsize("base/checkpoint.pt")))
write_results("results/merge.json", {"adapter_bytes": a, "merged_bytes": b, "max_logit_diff": max_logit_difference(m, merged, x)})
