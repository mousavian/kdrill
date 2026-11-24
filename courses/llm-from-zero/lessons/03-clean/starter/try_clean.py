"""Clean the first raw book and show before/after.  make py F=try_clean.py"""
import os

from clean import clean_book

names = sorted(n for n in os.listdir("data/raw") if n.endswith(".txt"))
raw = open(os.path.join("data/raw", names[0]), encoding="utf-8").read()
out = clean_book(raw)
print(names[0], len(raw), "->", len(out), "characters")
print("--- first 600 characters of the cleaned text")
print(out[:600])
os.makedirs("data/clean", exist_ok=True)
