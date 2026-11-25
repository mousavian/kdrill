"""Write the committed task files (pylib/kdlib/data/*.jsonl) from kdlib.tasks.  Run:
    PYTHONPATH=pylib python3 hack/make_tasks.py pylib/kdlib/data"""
import sys

from kdlib import tasks as T

out = sys.argv[1]
tr, ev = T.train_eval_qa()
rows, _ = T.make_raw_qa()
noisy, _ = T.make_noisy_qa()
T.write_jsonl(out + "/qa_train.jsonl", tr)
T.write_jsonl(out + "/qa_eval.jsonl", ev)
T.write_jsonl(out + "/qa_raw.jsonl", rows)
T.write_jsonl(out + "/qa_noisy.jsonl", noisy)
T.write_jsonl(out + "/pairs_raw.jsonl", T.make_raw_pairs()[0])
T.write_jsonl(out + "/pairs_train.jsonl", T.make_pairs(tr, seed=11))
T.write_jsonl(out + "/pairs_eval.jsonl", T.make_pairs(ev, seed=12))
import json
with open(out + "/facts.json", "w") as f:
    json.dump(T.FACTS, f, indent=1, sort_keys=True)
print("ok")
