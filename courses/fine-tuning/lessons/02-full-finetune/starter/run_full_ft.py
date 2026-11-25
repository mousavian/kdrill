"""Full fine-tuning at three learning rates.   make py F=run_full_ft.py   (about 35 s)
Prints style loss (Alice, held out) and original loss (Holmes, held out) after 150 steps for each learning rate."""
from base import clone, encode, load_base, read_text
from finetune import finetune
from harness import text_loss, write_results

base, tok = load_base()
train = encode(tok, read_text("alice_train"))
style_val, orig_val = encode(tok, read_text("alice_val")), encode(tok, read_text("holmes_val"))
rows = {"base": {"style_loss": text_loss(base, style_val), "orig_loss": text_loss(base, orig_val)}}
print("%-10s style %.3f  original %.3f" % ("base", rows["base"]["style_loss"], rows["base"]["orig_loss"]))
for lr in (3e-4, 1e-3, 3e-3):
    m = clone(base)
    finetune(m, train, steps=150, lr=lr)
    rows["lr=%g" % lr] = {"style_loss": text_loss(m, style_val), "orig_loss": text_loss(m, orig_val)}
    print("%-10s style %.3f  original %.3f" % ("lr=%g" % lr, rows["lr=%g" % lr]["style_loss"], rows["lr=%g" % lr]["orig_loss"]))
write_results("results/full_ft.json", rows)
