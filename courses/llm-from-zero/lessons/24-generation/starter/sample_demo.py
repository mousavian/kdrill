"""Sample from a checkpoint of your run_train.py (lesson 22), or from an untrained model if none exists.
  make py F=sample_demo.py"""
import os

import torch

from generate import generate
from gpt import GPT

tr = open("data/train.txt", encoding="utf-8").read()
chars = sorted(set(tr))
stoi = {c: i for i, c in enumerate(chars)}
model = GPT(len(chars), block_size=64, n_layer=3, n_head=4, n_embd=96)
if os.path.exists("out/ckpt.pt"):
    model.load_state_dict(torch.load("out/ckpt.pt", weights_only=False)["model"])
    print("loaded out/ckpt.pt")
else:
    print("no out/ckpt.pt (run run_train.py first): samples come from an untrained model")
prompt = torch.tensor([[stoi.get(c, 0) for c in "Holmes said"]])
for name, kw in [("greedy", dict(temperature=0)), ("temperature 0.7", dict(temperature=0.7)),
                 ("temperature 1.0", dict(temperature=1.0)), ("temp 1.0, top-k 10", dict(top_k=10)),
                 ("temp 1.0, top-p 0.9", dict(top_p=0.9)), ("greedy + repetition penalty 1.3", dict(temperature=0, repetition_penalty=1.3))]:
    g = torch.Generator().manual_seed(0)
    out = generate(model, prompt, 150, generator=g, **kw)[0].tolist()
    print("--- " + name)
    print("".join(chars[i] for i in out))
