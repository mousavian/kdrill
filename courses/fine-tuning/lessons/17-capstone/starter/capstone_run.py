"""Run the capstone on a task of your choice.
    make py F=capstone_run.py                      the course's own question-answer task
    make py F=capstone_run.py ARGS="data/my_task"  your task: data/my_task/train.jsonl and eval.jsonl, one {"question", "answer"} per line
Compares LoRA and full fine-tuning over 3 seeds (about 60 s) and writes out/capstone_lora/ and out/capstone_full/."""
import json
import sys

from capstone import run_capstone

folder = sys.argv[1] if len(sys.argv) > 1 else None
rd = lambda p: [json.loads(l) for l in open(p, encoding="utf-8") if l.strip()]
if folder:
    train, ev = rd(folder + "/train.jsonl"), rd(folder + "/eval.jsonl")
else:
    train, ev = rd("data/qa_train.jsonl"), rd("data/qa_eval.jsonl")[:60]

# TODO (yours): write what this model cannot do, in your own words, before you run it
LIMITATIONS = "TODO: say what the model cannot do and where the data is thin (at least twenty words)."

for method, cfg in (("lora", dict(steps=250, lr=3e-3)), ("full", dict(steps=150, lr=5e-4))):
    r = run_capstone(train, ev, "out/capstone_%s" % method, dict(cfg, method=method, seeds=[0, 1, 2]), LIMITATIONS)
    print("%-5s trainable %7d | base exact %.3f format %.3f | tuned exact %.3f +- %.3f format %.3f | original loss %s -> %s" % (
        method, r["trainable"], r["base"]["exact"], r["base"]["format"], r["tuned"]["exact"], r["exact_std"], r["tuned"]["format"],
        "%.3f" % r["base"]["orig_loss"], "%.3f" % r["tuned"]["orig_loss"]))
print("model cards: out/capstone_lora/MODEL_CARD.md, out/capstone_full/MODEL_CARD.md")
