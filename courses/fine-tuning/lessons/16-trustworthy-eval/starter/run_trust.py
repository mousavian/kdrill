"""Contamination and seed noise on this course's own data.   make py F=run_trust.py   (about 45 s)"""
import json

from base import clone, encode, load_base, read_text
from harness import text_loss
from sweep import lora_run
from trust import binomial_se, contaminated, decontaminate, overlap_rate, paired_summary

rd = lambda p: [json.loads(l) for l in open(p, encoding="utf-8") if l.strip()]
# 1. contamination
for a, b in (("alice_train", "alice_val"), ("alice_train", "alice_test"), ("holmes_train", "alice_val"), ("holmes_train", "holmes_test")):
    tr = [p for p in read_text(a).split("\n\n") if p.strip()]
    ev = [p for p in read_text(b).split("\n\n") if p.strip()]
    print("%-13s -> %-11s: 8-gram overlap %.4f, %d of %d eval paragraphs contaminated" % (a, b, overlap_rate(ev, tr, 8), sum(contaminated(ev, tr, 8)), len(ev)))
qa_tr, qa_ev = rd("data/qa_train.jsonl"), rd("data/qa_eval.jsonl")
kept, removed = decontaminate(qa_tr + qa_ev[:5], qa_ev, n=8)
print("question files: %d training rows share a whole question with the eval set (5 planted)" % len(removed))

# 2. seeds
base, tok = load_base()
train, val = encode(tok, read_text("alice_train")), encode(tok, read_text("alice_val"))
seeds = [0, 1, 2, 3]
low = [-lora_run(base, train, val, 2, 4, steps=80, seed=s)["val_loss"] for s in seeds]
high = [-lora_run(base, train, val, 8, 16, steps=80, seed=s)["val_loss"] for s in seeds]
s = paired_summary(low, high)
print("\nscore = minus style loss, 4 seeds: rank 2: %.3f +- %.3f   rank 8: %.3f +- %.3f" % (s["mean_a"], s["std_a"], s["mean_b"], s["std_b"]))
print("rank 8 minus rank 2: %+.3f with a 95%% half-width of %.3f -> %s" % (s["diff"], s["ci"], "a real difference" if s["b_better"] else "within the noise"))
print("exact match 0.55 on 100 questions has a standard error of %.3f; on 400 questions %.3f" % (binomial_se(0.55, 100), binomial_se(0.55, 400)))
