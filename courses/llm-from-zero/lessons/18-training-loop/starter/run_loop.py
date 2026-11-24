"""Train the BigramLM of this lesson on your real data.  make py F=run_loop.py"""
import torch

from loop import BigramLM, train

tr = open("data/train.txt", encoding="utf-8").read()
va = open("data/val.txt", encoding="utf-8").read()
chars = sorted(set(tr))
stoi = {c: i for i, c in enumerate(chars)}
enc = lambda s: torch.tensor([stoi.get(c, 0) for c in s], dtype=torch.long)
model = BigramLM(len(chars))
train(model, enc(tr), enc(va), block_size=8, batch_size=64, steps=1500, lr=0.05, eval_every=300)
