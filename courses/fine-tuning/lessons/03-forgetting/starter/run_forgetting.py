"""Forgetting versus replay.   make py F=run_forgetting.py   (about 60 s)
For two learning rates and three replay shares: style loss (want low), original loss (want it to stay near the base)
and the relative damage to the original text."""
from base import clone, encode, load_base, read_text
from forgetting import finetune_mixed, forgetting
from harness import text_loss, write_results

base, tok = load_base()
new, old = encode(tok, read_text("alice_train")), encode(tok, read_text("holmes_train"))
style_val, orig_val = encode(tok, read_text("alice_val")), encode(tok, read_text("holmes_val"))
b_style, b_orig = text_loss(base, style_val), text_loss(base, orig_val)
print("base: style %.3f original %.3f" % (b_style, b_orig))
rows = {}
for lr in (3e-4, 1e-3):
    for replay in (0.0, 0.25, 0.5):
        m = clone(base)
        finetune_mixed(m, new, old, steps=150, lr=lr, replay=replay)
        s, o = text_loss(m, style_val), text_loss(m, orig_val)
        rows["lr=%g replay=%g" % (lr, replay)] = {"style_loss": s, "orig_loss": o, "forgetting": forgetting(b_orig, o)}
        print("lr %-6g replay %.2f  style %.3f  original %.3f  forgetting %+.1f%%" % (lr, replay, s, o, 100 * forgetting(b_orig, o)))
write_results("results/forgetting.json", rows)
