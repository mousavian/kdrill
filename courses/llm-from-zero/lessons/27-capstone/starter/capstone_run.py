"""Run the capstone on a corpus of your choice.

  1. Put plain-text files (a few MB is plenty: another Gutenberg author, your own writing, ...) in
     data/my_corpus/   (lesson 01's fetcher can download them; sources.json shows the format)
  2. make py F=capstone_run.py ARGS="data/my_corpus"        about 4 minutes
  3. read out/capstone/MODEL_CARD.md and out/capstone/data/DATA_CARD.md, edit the limitations in prepare.py
"""
import sys

from capstone import run_pipeline

raw = sys.argv[1] if len(sys.argv) > 1 else "data/raw"
cfg = dict(merges=300, block_size=64, n_layer=3, n_head=4, n_embd=96, batch_size=32, max_steps=1500, warmup_steps=100,
           max_lr=3e-3, min_lr=3e-4, eval_every=250, eval_iters=20, save_every=500, dropout=0.1, sample_tokens=120)
res = run_pipeline(raw, "out/capstone", cfg)
for k, v in res.items():
    if k != "samples":
        print("%-16s %s" % (k, v))
for s in res["samples"]:
    print("---\n" + s)
