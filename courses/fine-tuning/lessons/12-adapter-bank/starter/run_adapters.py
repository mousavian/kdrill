"""Two adapters on one base, evaluated on both tasks.   make py F=run_adapters.py   (about 30 s)"""
import json

from base import clone, encode, load_base, read_text
from adapters import AdapterBank
from finetune import finetune
from harness import evaluate_qa, text_loss, write_results
from masking import train_sft
from sft_data import encode_all

base, tok = load_base()
model = clone(base)
bank = AdapterBank(model)
style_train, style_val = encode(tok, read_text("alice_train")), encode(tok, read_text("alice_val"))
with open("data/qa_train.jsonl", encoding="utf-8") as f:
    items, _ = encode_all(tok, [json.loads(l) for l in f if l.strip()], base.block_size)
with open("data/qa_eval.jsonl", encoding="utf-8") as f:
    ev = [json.loads(l) for l in f if l.strip()][:40]

bank.add("style")
bank.activate("style")
finetune(model, style_train, steps=100, lr=3e-3, warmup=10)
bank.add("qa")
bank.activate("qa")
train_sft(model, items, steps=250, lr=3e-3)

print("%-8s %12s %8s %8s" % ("adapter", "style loss", "format", "exact"))
rows = {}
for name in (None, "style", "qa"):
    bank.activate(name)
    q = evaluate_qa(model, tok, ev)
    rows[str(name)] = {"style_loss": text_loss(model, style_val), "format": q["format"], "exact": q["exact"]}
    print("%-8s %12.3f %8.2f %8.2f" % (name, rows[str(name)]["style_loss"], q["format"], q["exact"]))
rep = bank.memory_report()
print("one base %d bytes + adapters %s; two separate models would need %d bytes" % (rep["base_bytes"], rep["adapter_bytes"], rep["separate_models_bytes"] + 0))
write_results("results/adapters.json", {"table": rows, "memory": rep})
