"""Measure the base model and save results/baseline.json.   make py F=baseline.py   (about 15 s)"""
import json

from base import encode, load_base, read_text
from harness import evaluate, write_results

model, tok = load_base()
with open("data/qa_eval.jsonl", encoding="utf-8") as f:
    qa = [json.loads(l) for l in f if l.strip()]
res = evaluate(model, tok, encode(tok, read_text("alice_val")), encode(tok, read_text("holmes_val")), qa[:40])
write_results("results/baseline.json", res)
for k, v in res.items():
    print("%-12s %s" % (k, ("%.4f" % v) if isinstance(v, float) else v))
print("wrote results/baseline.json")
