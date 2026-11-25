"""Build the bundled style corpus (pylib/kdlib/data/alice_{train,val,test}.txt.gz).

    python3 hack/make_alice.py /path/to/11-0.txt pylib/kdlib/data

Input: Project Gutenberg #11, Alice's Adventures in Wonderland (public domain), exactly the file
pinned in pylib/kdlib/data/SOURCES.md. The text is cleaned the way llm-from-zero cleans Holmes:
header and footer removed, hard-wrapped lines joined into paragraphs, curly quotes and dashes to
ASCII, markup underscores dropped. The twelve chapters are split by chapter (no leakage):
chapters I-VIII train, IX-X validation, XI-XII test.
"""
import gzip
import re
import sys

src, out = sys.argv[1], sys.argv[2]
raw = open(src, encoding="utf-8").read()
body = raw.split("*** START OF THE PROJECT GUTENBERG EBOOK 11 ***")[1].split("*** END OF THE PROJECT GUTENBERG EBOOK 11 ***")[0]
body = body.replace("[Illustration]", "")
table = {"’": "'", "‘": "'", "“": '"', "”": '"', "—": "--", "–": "-", "_": "", "﻿": ""}
for k, v in table.items():
    body = body.replace(k, v)
parts = re.split(r"\n(CHAPTER [IVX]+\.)\n", body)
chapters = []
for i in range(1, len(parts), 2):
    title_and_text = parts[i + 1].strip("\n")
    lines = title_and_text.split("\n")
    title = lines[0].strip()
    text = "\n".join(lines[1:])
    paras = [" ".join(p.split()) for p in re.split(r"\n\s*\n", text) if p.strip()]
    chapters.append("Chapter %s %s\n\n%s\n" % (parts[i].split()[1].rstrip("."), title, "\n\n".join(paras)))
assert len(chapters) == 12, len(chapters)
split = {"train": chapters[:8], "val": chapters[8:10], "test": chapters[10:]}
for name, chs in split.items():
    text = "\n".join(chs)
    with open("%s/alice_%s.txt.gz" % (out, name), "wb") as f:
        with gzip.GzipFile(fileobj=f, mode="wb", compresslevel=9, mtime=0) as g:
            g.write(text.encode("utf-8"))
    print(name, len(chs), "chapters", len(text), "characters")
