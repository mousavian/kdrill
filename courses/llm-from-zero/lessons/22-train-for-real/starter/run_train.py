"""A real training run on your data: a small GPT on the training split, a few minutes on 2 CPUs.
  make py F=run_train.py            (about 2 minutes; it saves out/ckpt.pt, run again to see it resume)
Uses a character tokenizer if you wrote lesson 07, else raw characters."""
import os
import sys

import torch

from gpt import GPT
from train_gpt import train_run

tr = open("data/train.txt", encoding="utf-8").read()
va = open("data/val.txt", encoding="utf-8").read()
chars = sorted(set(tr))
stoi = {c: i for i, c in enumerate(chars)}
enc = lambda s: torch.tensor([stoi.get(c, 0) for c in s], dtype=torch.long)
torch.manual_seed(0)
model = GPT(len(chars), block_size=64, n_layer=3, n_head=4, n_embd=96)
print("parameters:", model.num_params())
cfg = dict(block_size=64, batch_size=32, max_steps=1500, warmup_steps=100, max_lr=3e-3, min_lr=3e-4,
           weight_decay=0.1, grad_clip=1.0, eval_every=250, eval_iters=20, save_every=250, seed=1)
resume = os.path.exists("out/ckpt.pt")
print("resuming from out/ckpt.pt" if resume else "starting fresh")
res = train_run(model, enc(tr), enc(va), cfg, "out", resume=resume)
for e in res["evals"]:
    print("step %5d  val loss %.4f" % (e["step"], e["val_loss"]))
