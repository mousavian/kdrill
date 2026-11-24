"""Download the pinned books listed in data/sources.json into data/raw.

Run it with:  make py F=gather.py      (needs the network; the lesson declares it)
Safe to run again: files that are already there and match their checksum are kept.
"""
import json

from fetcher import fetch_all

with open("data/sources.json", encoding="utf-8") as f:
    books = json.load(f)["books"]

manifest = fetch_all(books, "data/raw")
for m in manifest:
    print("%-40s %9d bytes  sha256 %s..." % (m["title"], m["bytes"], m["sha256"][:12]))
print("wrote data/raw/manifest.json")
