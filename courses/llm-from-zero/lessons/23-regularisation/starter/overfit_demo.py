"""See overfitting and the cures on a small slice of your data.  make py F=overfit_demo.py  (about a minute)
A model that is big for 6,000 characters trains until its training loss is low and its validation loss climbs."""
import torch

from gpt import GPT
from loop import evaluate
from regularize import train_with_early_stopping

tr = open("data/train.txt", encoding="utf-8").read()[:6000]
va = open("data/val.txt", encoding="utf-8").read()[:20000]
chars = sorted(set(open("data/train.txt", encoding="utf-8").read()))
stoi = {c: i for i, c in enumerate(chars)}
enc = lambda s: torch.tensor([stoi.get(c, 0) for c in s], dtype=torch.long)
for name, dropout, wd in [("no regularisation", 0.0, 0.0), ("dropout 0.2 + weight decay 0.1", 0.2, 0.1)]:
    torch.manual_seed(0)
    m = GPT(len(chars), 32, 3, 4, 96, dropout=dropout)
    res = train_with_early_stopping(m, enc(tr), enc(va), 32, 32, 600, 2e-3, wd, 50, 10, patience=100)
    print("--- " + name)
    for step, a, b in res["history"][::2]:
        print("  step %4d train %.3f val %.3f gap %.3f" % (step, a, b, b - a))
