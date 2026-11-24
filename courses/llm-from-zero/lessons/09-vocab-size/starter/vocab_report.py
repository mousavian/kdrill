"""Run the study on the real training split (about a minute).  make py F=vocab_report.py
Then write your choice and your reasons, with numbers, into vocab_choice.json."""
from vocab_study import choose_size, embedding_params, study

train = open("data/train.txt", encoding="utf-8").read()[:500000]
val = open("data/val.txt", encoding="utf-8").read()[:100000]
sizes = [260, 300, 400, 600, 1000, 1500, 2000]
rows = study(train, val, sizes)
print("%6s %7s %10s %10s %9s %14s" % ("vocab", "merges", "tok/word", "bytes/tok", "rare", "emb params d=64"))
for r in rows:
    print("%6d %7d %10.3f %10.3f %9.3f %14d" % (r["vocab_size"], r["merges"], r["tokens_per_word"], r["bytes_per_token"],
                                                r["rare_fraction"], embedding_params(r["vocab_size"], 64)))
print("choose_size ->", choose_size(rows))
