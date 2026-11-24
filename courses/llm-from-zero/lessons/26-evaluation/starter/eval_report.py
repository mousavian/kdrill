"""Evaluate the checkpoint from run_train.py on the TEST split (the first and only time you touch it).
  make py F=eval_report.py
Run run_train.py (lesson 22) first; without out/ckpt.pt this evaluates an untrained model."""
import math
import os

import torch

from evaluation import bits_per_char, contamination, perplexity_on_text, run_probes
from gpt import GPT

tr = open("data/train.txt", encoding="utf-8").read()
te = open("data/test.txt", encoding="utf-8").read()
chars = sorted(set(tr))
stoi = {c: i for i, c in enumerate(chars)}
enc = lambda s: [stoi.get(c, 0) for c in s]
model = GPT(len(chars), block_size=64, n_layer=3, n_head=4, n_embd=96)
if os.path.exists("out/ckpt.pt"):
    model.load_state_dict(torch.load("out/ckpt.pt", weights_only=False)["model"])
ids = torch.tensor(enc(te))
r = perplexity_on_text(model, ids, stride=16)
print("test loss %.4f nats/char, perplexity %.2f, %.3f bits per char (%d tokens)"
      % (r["loss"], r["perplexity"], bits_per_char(r["loss"], r["tokens"], len(te)), r["tokens"]))
rate, ex = contamination(tr, te)
print("8-gram contamination of test by train: %.4f" % rate, ex)
probes = [{"prompt": "Mr. Sherlock ", "good": "Holmes", "bad": ["Hqxzy", "Aaaaaa"]},
          {"prompt": "\"I do not ", "good": "know", "bad": ["kzqx", "xxxx"]}]
print(run_probes(model, enc, probes)["accuracy"], "of the probes passed")
