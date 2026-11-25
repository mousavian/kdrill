"""Same budget, noisy versus validated data.   make py F=run_quality.py   (about 20 s)
data/qa_noisy.jsonl has 300 examples, about a third with a wrong answer. Both runs train 250 steps."""
import json

from base import clone, load_base
from harness import evaluate_qa, write_results
from masking import train_sft
from quality import load_facts, noise_rate, split_clean
from sft_data import encode_all

base, tok = load_base()
with open("data/qa_noisy.jsonl", encoding="utf-8") as f:
    rows = [json.loads(l) for l in f if l.strip()]
with open("data/qa_eval.jsonl", encoding="utf-8") as f:
    ev = [json.loads(l) for l in f if l.strip()]
facts = load_facts()
kept, dropped = split_clean(rows, facts)
print("%d rows, noise rate %.2f; kept %d, dropped %d" % (len(rows), noise_rate(rows, facts), len(kept), len(dropped)))
out = {}
for name, data in (("noisy (all %d)" % len(rows), rows), ("validated (%d)" % len(kept), kept)):
    m = clone(base)
    items, _ = encode_all(tok, data, base.block_size)
    train_sft(m, items, steps=250, lr=2e-3)
    out[name] = evaluate_qa(m, tok, ev[:60])
    print("%-18s format %.2f  exact %.2f" % (name, out[name]["format"], out[name]["exact"]))
write_results("results/quality.json", out)
