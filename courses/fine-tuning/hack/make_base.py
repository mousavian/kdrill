"""Train the reference base model (pylib/kdlib/data/ref_base.pt): a small GPT on the bundled Holmes text.

    docker run ... python3 make_base.py OUT_DIR       (see hack/make_assets.sh)

The same recipe as the llm-from-zero capstone (BPE trained on the training split only, GPT-2 style
init, AdamW with warm-up and cosine decay, clipping), with a context of 64 tokens, which the
fine-tuning lessons need. About 3 minutes on 4 CPUs. The result is committed (about 1.5 MB), so
nothing here runs for a learner.
"""
import gzip
import math
import os
import sys
import time

import torch

from kdlib import refmodel as R
from kdlib.tasks import holmes

OUT = sys.argv[1]
STEPS = int(sys.argv[2]) if len(sys.argv) > 2 else 2500
cfg = dict(merges=200, block_size=64, n_layer=3, n_head=4, n_embd=96, dropout=0.0, batch_size=32,
           max_steps=STEPS, warmup_steps=60, max_lr=4e-3, min_lr=4e-4, weight_decay=0.1, grad_clip=1.0, seed=0)
torch.set_num_threads(int(os.environ.get("OMP_NUM_THREADS", "2")))
tr, va, te = holmes("train"), holmes("val"), holmes("test")
t0 = time.time()
tok = R.BPE.train(tr, cfg["merges"])
print("bpe %.0fs, vocab %d" % (time.time() - t0, tok.vocab_size))
ids = {k: torch.tensor(tok.encode(t), dtype=torch.long) for k, t in (("train", tr), ("val", va), ("test", te))}
print({k: len(v) for k, v in ids.items()})
gcfg = dict(vocab_size=tok.vocab_size, block_size=cfg["block_size"], n_layer=cfg["n_layer"], n_head=cfg["n_head"],
            n_embd=cfg["n_embd"], dropout=0.0)
torch.manual_seed(cfg["seed"])
model = R.GPT(**gcfg)
print("params", model.num_params())
opt = torch.optim.AdamW(model.parameters(), lr=cfg["max_lr"], betas=(0.9, 0.95), weight_decay=cfg["weight_decay"])
g = torch.Generator().manual_seed(cfg["seed"])
B, T = cfg["batch_size"], cfg["block_size"]


def batch(data):
    ix = torch.randint(0, len(data) - T - 1, (B,), generator=g)
    return torch.stack([data[i:i + T] for i in ix.tolist()]), torch.stack([data[i + 1:i + T + 1] for i in ix.tolist()])


def lr_at(s):
    if s < cfg["warmup_steps"]:
        return cfg["max_lr"] * (s + 1) / cfg["warmup_steps"]
    r = (s - cfg["warmup_steps"]) / max(1, cfg["max_steps"] - cfg["warmup_steps"])
    return cfg["min_lr"] + 0.5 * (1 + math.cos(math.pi * r)) * (cfg["max_lr"] - cfg["min_lr"])


@torch.no_grad()
def val_loss(data):
    model.eval()
    tot, n = 0.0, 0
    for s in range(0, len(data) - T - 1, T):
        x, y = data[s:s + T][None], data[s + 1:s + T + 1][None]
        tot += model(x, y)[1].item(); n += 1
    model.train()
    return tot / n


for s in range(cfg["max_steps"]):
    for pg in opt.param_groups:
        pg["lr"] = lr_at(s)
    x, y = batch(ids["train"])
    _, loss = model(x, y)
    opt.zero_grad(set_to_none=True)
    loss.backward()
    torch.nn.utils.clip_grad_norm_(model.parameters(), cfg["grad_clip"])
    opt.step()
    if s % 100 == 0 or s == cfg["max_steps"] - 1:
        print("step %d loss %.3f val %.3f  %.0fs" % (s, loss.item(), val_loss(ids["val"]), time.time() - t0), flush=True)
metrics = {"val_loss": val_loss(ids["val"]), "test_loss": val_loss(ids["test"])}
metrics["test_perplexity"] = math.exp(metrics["test_loss"])
os.makedirs(OUT, exist_ok=True)
torch.save({"model_state": model.state_dict(), "gpt_config": gcfg, "tokenizer": tok.to_dict(), "metrics": metrics,
            "train_config": cfg, "data_card": "Holmes: the bundled cleaned Sherlock Holmes text of llm-from-zero.",
            "course": "llm-from-zero"}, os.path.join(OUT, "ref_base.pt"))
print("saved", metrics)
