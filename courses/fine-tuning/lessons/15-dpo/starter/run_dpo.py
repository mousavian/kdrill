"""DPO on the half-chatty SFT model.   make py F=run_dpo.py   (about 25 s)
Before and after, for three values of beta: the share of chatty answers (greedy, 40 held-out prompts), the win rate on
the held-out pairs, and how often the answer still contains the right word."""
import json

from base import clone, load_base
from dpo import dpo_train, reference_logprobs, win_rate
from harness import complete, write_results
from prefs import clean_pairs, is_chatty

sft, tok = load_base("models/sft_mixed.pt")
rd = lambda p: [json.loads(l) for l in open(p, encoding="utf-8") if l.strip()]
train = rd("data/pairs_train.jsonl")
ev_pairs, ev_q = rd("data/pairs_eval.jsonl"), rd("data/qa_eval.jsonl")[:40]


def measure(m):
    outs = [(complete(m, tok, "Q: %s\nA:" % r["question"])[0], r["answer"]) for r in ev_q]
    return {"chatty": sum(is_chatty(t) for t, _ in outs) / len(outs), "has_answer": sum(a in t for t, a in outs) / len(outs)}


ref_lp = reference_logprobs(sft, tok, train)
rows = {"SFT": dict(measure(sft), win_rate=0.0)}
print("%-10s chatty %.2f  has answer %.2f" % ("SFT", rows["SFT"]["chatty"], rows["SFT"]["has_answer"]))
for beta in (0.05, 0.1, 0.5):
    policy = clone(sft)
    losses = dpo_train(policy, ref_lp, tok, train, steps=60, lr=5e-5, beta=beta)
    rows["beta=%g" % beta] = dict(measure(policy), win_rate=win_rate(policy, sft, tok, ev_pairs), loss_first=losses[0], loss_last=losses[-1])
    r = rows["beta=%g" % beta]
    print("beta=%-5g chatty %.2f  has answer %.2f  win rate %.2f  loss %.3f -> %.3f" % (beta, r["chatty"], r["has_answer"], r["win_rate"], losses[0], losses[-1]))
write_results("results/dpo.json", rows)
