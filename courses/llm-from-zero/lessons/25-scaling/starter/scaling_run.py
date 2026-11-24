"""The experiment: four model sizes, two compute budgets. About 2.5 minutes on 2 CPUs.
  make py F=scaling_run.py          (writes out/scaling.png and prints the table)
Edit CONFIGS and BUDGET to explore. Bigger models get FEWER steps for the same compute."""
import torch

from scaling import fit_power_law, plot_curves, run_one

tr = open("data/train.txt", encoding="utf-8").read()
va = open("data/val.txt", encoding="utf-8").read()
chars = sorted(set(tr))
stoi = {c: i for i, c in enumerate(chars)}
enc = lambda s: torch.tensor([stoi.get(c, 0) for c in s], dtype=torch.long)
train_ids, val_ids = enc(tr), enc(va)
CONFIGS = [dict(n_layer=2, n_head=2, n_embd=32), dict(n_layer=2, n_head=4, n_embd=64),
           dict(n_layer=3, n_head=4, n_embd=96), dict(n_layer=4, n_head=4, n_embd=128)]
BUDGETS = [2e11, 6e11]
curves = {}
for budget in BUDGETS:
    print("--- budget %.0e FLOPs" % budget)
    pts = []
    for cfg in CONFIGS:
        r = run_one(cfg, budget, train_ids, val_ids, len(chars))
        print("  N=%8d steps=%5d  train %.3f  val %.3f" % (r["n_params"], r["steps"], r["train_loss"], r["val_loss"]))
        pts.append((r["n_params"], r["val_loss"]))
    curves["budget %.0e" % budget] = pts
plot_curves(curves, "out/scaling.png", xlabel="parameters", ylabel="validation loss (fixed compute per curve)",
            title="Model size at fixed compute")
print("wrote out/scaling.png")
