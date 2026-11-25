"""Fine-tune the base model to answer in the format.   make py F=run_sft.py   (about 25 s)
Trains twice with the same budget: loss on the answer tokens only, and on all tokens (mask of ones)."""
import copy
import json

from base import clone, load_base
from harness import evaluate_qa, write_results
from masking import train_sft
from sft_data import encode_all

base, tok = load_base()
with open("data/qa_train.jsonl", encoding="utf-8") as f:
    train = [json.loads(l) for l in f if l.strip()]
with open("data/qa_eval.jsonl", encoding="utf-8") as f:
    ev = [json.loads(l) for l in f if l.strip()]
items, dropped = encode_all(tok, train, base.block_size)
print("%d training items (%d dropped as too long)" % (len(items), dropped))
before = evaluate_qa(base, tok, ev[:50])
print("base            format %.2f  exact %.2f" % (before["format"], before["exact"]))
rows = {"base": before}
for name, its in (("answer tokens", items), ("all tokens", [(ids, 1) for ids, _ in items])):
    m = clone(base)
    train_sft(m, its, steps=250, lr=2e-3)
    r = evaluate_qa(m, tok, ev)
    rows[name] = r
    print("%-15s format %.2f  exact %.2f" % (name, r["format"], r["exact"]))
write_results("results/sft.json", rows)
