"""Attention only, MLP only, both.   make py F=run_targets.py   (about 35 s)
Question-answer task, rank 8, 250 steps. Exact match on 60 held-out questions."""
import json

from base import load_base
from sft_data import encode_all
from harness import write_results
from targets import compare_targets

base, tok = load_base()
with open("data/qa_train.jsonl", encoding="utf-8") as f:
    train = [json.loads(l) for l in f if l.strip()]
with open("data/qa_eval.jsonl", encoding="utf-8") as f:
    ev = [json.loads(l) for l in f if l.strip()]
items, _ = encode_all(tok, train, base.block_size)
rows = compare_targets(base, tok, items, ev[:60], ["qv", "attention", "mlp", "attention+mlp"])
for r in rows:
    print("%-14s trainable %6d (predicted %6d)  format %.2f  exact %.2f" % (r["group"], r["trainable"], r["predicted"], r["format"], r["exact"]))
write_results("results/targets.json", {r["group"]: r for r in rows})
