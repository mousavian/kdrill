"""Regenerate the bundled cleaned corpus (pylib/kdlib/data/clean_*.txt.gz).

Run inside the course image with the reference solutions on the path:
    hack/make_bundle.sh
Two public-domain books (244, 2097) are cleaned with the reference pipeline, cut into
24 contiguous pseudo-documents (about a dozen per book) and split by document.
"""
import gzip
import os
import sys

from clean import clean_book
from dedup import filter_and_dedup, paragraphs
from kdlib.corpus import bundled_raw
from split import split_documents

CHUNKS_PER_BOOK = 12
docs, all_paras = {}, []
for book in (244, 2097):
    paras = paragraphs(clean_book(bundled_raw(book)))
    all_paras.append((book, paras))
flat = [(b, p) for b, ps in all_paras for p in ps]
kept, stats = filter_and_dedup([p for _, p in flat])
print(stats)
j, per_book = 0, {}
for b, p in flat:
    if j < len(kept) and kept[j] == p:
        per_book.setdefault(b, []).append(p)
        j += 1
for b, ps in per_book.items():
    n = len(ps)
    for c in range(CHUNKS_PER_BOOK):
        chunk = ps[c * n // CHUNKS_PER_BOOK:(c + 1) * n // CHUNKS_PER_BOOK]
        docs["%d-%02d" % (b, c)] = "\n\n".join(chunk) + "\n"
asg = split_documents(docs, seed=7)
out = sys.argv[1]
for s in ("train", "val", "test"):
    text = "\n\n".join(docs[n].strip() for n in sorted(asg[s])) + "\n"
    with open(os.path.join(out, "clean_%s.txt.gz" % s), "wb") as f:
        with gzip.GzipFile(fileobj=f, mode="wb", compresslevel=9, mtime=0) as g:
            g.write(text.encode("utf-8"))
    print(s, len(asg[s]), "documents", len(text), "characters")
