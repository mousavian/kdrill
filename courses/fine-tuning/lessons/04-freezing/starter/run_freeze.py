"""Which part to train?   make py F=run_freeze.py   (about 30 s)
Same budget (150 steps, lr 1e-3) for: everything, the last two blocks, the last block, only the final norm."""
from base import clone, encode, load_base, read_text
from freeze import param_report, train_subset
from harness import text_loss, write_results

base, tok = load_base()
train = encode(tok, read_text("alice_train"))
style_val, orig_val = encode(tok, read_text("alice_val")), encode(tok, read_text("holmes_val"))
n = len(base.blocks)
setups = {"everything": [""],
          "last 2 blocks": ["blocks.%d." % i for i in range(n - 2, n)] + ["ln_f."],
          "last block": ["blocks.%d." % (n - 1), "ln_f."],
          "final norm only": ["ln_f."]}
print("base: style %.3f original %.3f" % (text_loss(base, style_val), text_loss(base, orig_val)))
rows = {}
for name, prefixes in setups.items():
    m = clone(base)
    r = train_subset(m, train, prefixes, steps=150, lr=1e-3)
    rows[name] = {"trainable": r["report"]["trainable"], "style_loss": text_loss(m, style_val), "orig_loss": text_loss(m, orig_val)}
    print("%-16s trainable %7d (%4.1f%%)  style %.3f  original %.3f" % (name, r["report"]["trainable"], 100 * r["report"]["fraction"], rows[name]["style_loss"], rows[name]["orig_loss"]))
write_results("results/freeze.json", rows)
