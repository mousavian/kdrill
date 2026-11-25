"""LoRA on the style task.   make py F=run_lora.py   (about 20 s)
Attention-only adapters (rank 8) trained with the finetune() of lesson 02, which already trains only what requires grad."""
import os

from base import clone, encode, load_base, read_text
from finetune import finetune
from harness import text_loss, write_results
from lora import add_lora, save_adapter, trainable_count

base, tok = load_base()
train = encode(tok, read_text("alice_train"))
style_val, orig_val = encode(tok, read_text("alice_val")), encode(tok, read_text("holmes_val"))
total = sum(p.numel() for p in base.parameters())
print("base: style %.3f original %.3f   (%d parameters)" % (text_loss(base, style_val), text_loss(base, orig_val), total))
m = clone(base)
names = add_lora(m, r=8, alpha=16)
print("%d layers wrapped, %d trainable parameters (%.1f%% of the model)" % (len(names), trainable_count(m), 100 * trainable_count(m) / total))
finetune(m, train, steps=150, lr=3e-3, warmup=10)
size = save_adapter(m, "adapters/style.pt")
print("LoRA r=8: style %.3f original %.3f; adapter file %d bytes (the full checkpoint is %d)" % (
    text_loss(m, style_val), text_loss(m, orig_val), size, os.path.getsize("base/checkpoint.pt")))
write_results("results/lora.json", {"style_loss": text_loss(m, style_val), "orig_loss": text_loss(m, orig_val),
                                   "trainable": trainable_count(m), "adapter_bytes": size})
