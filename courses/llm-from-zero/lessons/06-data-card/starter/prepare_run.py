"""Build the real dataset into data/ and show the card.  make py F=prepare_run.py"""
from prepare import build_dataset

stats = build_dataset("data/raw", "data")
print(open("data/DATA_CARD.md", encoding="utf-8").read())
