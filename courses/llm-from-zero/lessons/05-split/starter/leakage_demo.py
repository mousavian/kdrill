"""Why a random line split lies.  make py F=leakage_demo.py
Splits the cleaned corpus both ways and compares how much of the validation text the
training text has already 'seen'."""
import os

import split

try:
    from clean import clean_book
except Exception:
    clean_book = lambda t: t

docs = {}
for n in sorted(os.listdir("data/raw")):
    if n.endswith(".txt"):
        docs[n] = clean_book(open(os.path.join("data/raw", n), encoding="utf-8").read())

by_doc = split.split_documents(docs, seed=1)
train = "\n".join(docs[n] for n in by_doc["train"])
val = "\n".join(docs[n] for n in by_doc["val"])
print("documents  train:", by_doc["train"], " val:", by_doc["val"], " test:", by_doc["test"])

lines = [l for t in docs.values() for l in t.split("\n") if l.strip()]
tr, va = split.split_lines_randomly(lines, 0.1, seed=1)
print("%-22s %10s %10s" % ("", "by document", "by line"))
print("%-22s %10.4f %10.4f" % ("OOV rate", split.oov_rate(train, val), split.oov_rate("\n".join(tr), "\n".join(va))))
print("%-22s %10.4f %10.4f" % ("8-gram overlap", split.ngram_overlap(train, val), split.ngram_overlap("\n".join(tr), "\n".join(va))))
