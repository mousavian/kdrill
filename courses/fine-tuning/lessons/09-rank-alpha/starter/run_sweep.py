"""Rank and alpha sweeps.   make py F=run_sweep.py   (about 60 s)
Part 1: rank 1..16 with alpha = 2r (the scale alpha/r stays 2). Part 2: rank 8 with alpha from 1 to 64.
Reference point: full fine-tuning, 150 steps at lr 5e-4."""
from base import clone, encode, load_base, read_text
from finetune import finetune
from harness import text_loss, write_results
from sweep import run_sweep, smallest_rank

base, tok = load_base()
train = encode(tok, read_text("alice_train"))
val = encode(tok, read_text("alice_val"))
b = text_loss(base, val)
full = clone(base)
finetune(full, train, steps=150, lr=5e-4, warmup=10)
f = text_loss(full, val)
print("base %.3f   full fine-tuning %.3f" % (b, f))
print("\nrank sweep (alpha = 2r):")
ranks = run_sweep(base, train, val, [(r, 2 * r) for r in (1, 2, 4, 8, 16)], steps=100)
for x in ranks:
    print("  r=%-3d alpha=%-3g trainable %6d  val loss %.3f" % (x["r"], x["alpha"], x["trainable"], x["val_loss"]))
print("\nalpha sweep (r = 8):")
alphas = run_sweep(base, train, val, [(8, a) for a in (1, 4, 16, 64)], steps=100)
for x in alphas:
    print("  alpha=%-3g scale %.3f  val loss %.3f" % (x["alpha"], x["scale"], x["val_loss"]))
picks = {}
for frac in (0.5, 0.8):
    pick = smallest_rank(ranks, b, f, frac)
    picks[str(frac)] = pick
    print("\nsmallest rank with %d%% of the full gain: %s" % (100 * frac, ("r=%d (%d parameters)" % (pick["r"], pick["trainable"])) if pick else "none"))
write_results("results/sweep.json", {"base": b, "full": f, "ranks": ranks, "alphas": alphas, "picks": picks})
