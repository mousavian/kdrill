"""Clean the preference data and build the model DPO will start from.   make py F=run_prefs.py   (about 25 s)
1. clean data/pairs_raw.jsonl against the evaluation prompts; 2. fine-tune the base model on question-answer examples where
half of the answers are chatty (SFT with your train_sft) and save it to models/sft_mixed.pt; 3. measure how often it is chatty."""
import json

import torch

from base import clone, load_base
from harness import complete, write_results
from masking import train_sft
from prefs import clean_pairs, completion_logprobs, encode_pair, is_chatty, length_gap
from sft_data import encode_all

base, tok = load_base()
rd = lambda p: [json.loads(l) for l in open(p, encoding="utf-8") if l.strip()]
raw, ev_pairs, qa_train, qa_eval = rd("data/pairs_raw.jsonl"), rd("data/pairs_eval.jsonl"), rd("data/qa_train.jsonl"), rd("data/qa_eval.jsonl")
clean = clean_pairs(raw, [p["prompt"] for p in ev_pairs])
print("raw pairs %d -> clean %d;  length gap %s" % (len(raw), len(clean), length_gap(clean, tok)))

# the SFT model: half of the answers terse, half chatty (the same choice for every learner: data/pairs_train.jsonl has both versions)
mixed = [{"question": p["prompt"], "answer": (p["rejected"] if i % 2 else p["chosen"])} for i, p in enumerate(rd("data/pairs_train.jsonl"))]
items, dropped = encode_all(tok, mixed, base.block_size)
sft = clone(base)
train_sft(sft, items, steps=400, lr=2e-3)
chatty = sum(is_chatty(complete(sft, tok, "Q: %s\nA:" % r["question"])[0]) for r in qa_eval[:40]) / 40
c, r = [], []
with torch.no_grad():
    for p in ev_pairs[:60]:
        pr, ch, rj = encode_pair(tok, p)
        c.append(completion_logprobs(sft, [(pr, ch)])[0]); r.append(completion_logprobs(sft, [(pr, rj)])[0])
acc = float(sum(1 for a, b in zip(c, r) if a > b)) / len(c)
print("SFT model: chatty in %.0f%% of the answers; prefers the terse answer by raw log-probability on %.0f%% of held-out pairs" % (100 * chatty, 100 * acc))
import os
os.makedirs("models", exist_ok=True)
ck = torch.load("base/checkpoint.pt", weights_only=False)
ck["model_state"] = sft.state_dict()
torch.save(ck, "models/sft_mixed.pt")
write_results("results/prefs.json", {"clean_pairs": len(clean), "chatty_rate": chatty, "raw_logprob_accuracy": acc})
