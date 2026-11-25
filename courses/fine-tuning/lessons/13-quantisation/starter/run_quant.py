"""Memory and quality of quantised bases, and training adapters on top.   make py F=run_quant.py   (about 30 s)"""
from base import clone, encode, load_base, read_text
from finetune import finetune
from harness import text_loss, write_results
from lora import add_lora, trainable_count
from quant import model_bytes, quantize_model

base, tok = load_base()
val = encode(tok, read_text("alice_val"))
train = encode(tok, read_text("alice_train"))
orig = encode(tok, read_text("holmes_val"))
rows = {}


def show(name, m):
    rows[name] = {"bytes": model_bytes(m), "orig_loss": text_loss(m, orig), "style_loss": text_loss(m, val)}
    print("%-26s %9d bytes   holmes loss %.4f   alice loss %.4f" % (name, rows[name]["bytes"], rows[name]["orig_loss"], rows[name]["style_loss"]))


show("float32 base", base)
for bits in (8, 4):
    m = clone(base)
    quantize_model(m, bits=bits)
    show("%d-bit base" % bits, m)
for bits in (8, 4):
    m = clone(base)
    add_lora(m, r=8, alpha=16)
    quantize_model(m, bits=bits)       # the base inside every adapter layer is quantised; A and B stay float
    finetune(m, train, steps=100, lr=3e-3, warmup=10)
    show("%d-bit base + LoRA (%d tr.)" % (bits, trainable_count(m)), m)
write_results("results/quant.json", rows)
