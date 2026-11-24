"""What do the filters remove from the real corpus?  make py F=report_filters.py
Needs clean.py from lesson 03 (clean_book); falls back to raw paragraphs without it."""
import os

from dedup import filter_and_dedup, paragraphs

try:
    from clean import clean_book
except Exception:  # lesson 03 not done
    clean_book = lambda t: t

paras = []
for n in sorted(os.listdir("data/raw")):
    if n.endswith(".txt"):
        paras += paragraphs(clean_book(open(os.path.join("data/raw", n), encoding="utf-8").read()))
kept, stats = filter_and_dedup(paras)
for key, value in stats.items():
    print("%-18s %7d  %5.1f%%" % (key, value, 100 * value / stats["input"]))
