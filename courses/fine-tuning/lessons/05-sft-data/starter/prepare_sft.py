"""Prepare the instruction data.   make py F=prepare_sft.py   (a few seconds)
Reads data/qa_raw.jsonl (messy), cleans, splits and encodes; writes data/sft_train.jsonl and data/sft_eval.jsonl."""
import json

from base import load_base
from sft_data import clean_examples, dataset_stats, encode_all, format_example, split_examples

with open("data/qa_raw.jsonl", encoding="utf-8") as f:
    raw = [json.loads(l) for l in f if l.strip()]
model, tok = load_base()
clean = clean_examples(raw)
train, ev = split_examples(clean, 0.2, seed=0)
print("raw %d -> clean %d -> train %d / eval %d" % (len(raw), len(clean), len(train), len(ev)))
items, dropped = encode_all(tok, train, model.block_size)
print("encoded %d examples, %d too long" % (len(items), dropped), dataset_stats(items))
print(repr("".join(format_example(train[0]["question"], train[0]["answer"]))))
for name, rows in (("train", train), ("eval", ev)):
    with open("data/sft_%s.jsonl" % name, "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")
print("wrote data/sft_train.jsonl and data/sft_eval.jsonl")
