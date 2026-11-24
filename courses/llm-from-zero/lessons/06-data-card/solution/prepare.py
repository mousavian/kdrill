"""Lesson 06 - reference solution."""
import hashlib
import os

from clean import clean_book
from dedup import filter_and_dedup, paragraphs
from split import ngram_overlap, oov_rate, split_documents, words, write_splits

LIMITATIONS = [
    "One author and one narrator: the text is Arthur Conan Doyle's late-Victorian British English, so the model imitates that voice and its period vocabulary, spelling and attitudes (class, empire, gender), and knows nothing about modern English.",
    "Cleaning removed headers, footers, contents and illustration tags, turned curly quotes and dashes into ASCII ones and joined hard-wrapped lines; poems, tables and any layout that mattered are flattened.",
    "Only nine books (a few million characters): enough to learn spelling, punctuation and the style of a story, not enough to learn facts or long-range plot; generated stories will be fluent-looking nonsense.",
    "Validation and test are whole books chosen by seed: with so few documents their difficulty differs from book to book, so a small loss difference between two models is not trustworthy.",
]


def _sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def build_dataset(raw_dir, out_dir, seed=0):
    names = sorted(n for n in os.listdir(raw_dir) if n.endswith(".txt"))
    sources, raw_chars, cleaned = [], 0, {}
    for n in names:
        p = os.path.join(raw_dir, n)
        sources.append({"file": n, "bytes": os.path.getsize(p), "sha256": _sha256(p)})
        with open(p, encoding="utf-8") as f:
            raw = f.read()
        raw_chars += len(raw)
        cleaned[n] = paragraphs(clean_book(raw))

    flat = [(n, p) for n in names for p in cleaned[n]]
    kept, fstats = filter_and_dedup([p for _, p in flat])
    docs_paras = {n: [] for n in names}
    j = 0
    for n, p in flat:
        if j < len(kept) and kept[j] == p:
            docs_paras[n].append(p)
            j += 1
    docs = {n: "\n\n".join(ps) + "\n" for n, ps in docs_paras.items() if ps}

    assignment = split_documents(docs, seed=seed)
    write_splits(docs, assignment, out_dir)
    texts = {s: open(os.path.join(out_dir, s + ".txt"), encoding="utf-8").read() for s in ("train", "val", "test")}
    splits = {}
    for s, t in texts.items():
        splits[s] = {"documents": assignment[s], "chars": len(t), "words": len(words(t)),
                     "paragraphs": len(paragraphs(t))}
    stats = {
        "sources": sources,
        "raw_chars": raw_chars,
        "filters": fstats,
        "splits": splits,
        "clean_chars": sum(len(t) for t in texts.values()),
        "distinct_chars": len(set("".join(texts.values()))),
        "leakage": {
            "oov_val": oov_rate(texts["train"], texts["val"]), "oov_test": oov_rate(texts["train"], texts["test"]),
            "overlap_val": ngram_overlap(texts["train"], texts["val"]),
            "overlap_test": ngram_overlap(texts["train"], texts["test"]),
        },
    }
    with open(os.path.join(out_dir, "DATA_CARD.md"), "w", encoding="utf-8") as f:
        f.write(make_card(stats))
    return stats


def make_card(stats):
    f, s, lk = stats["filters"], stats["splits"], stats["leakage"]
    out = ["# Data card", "", "## Sources", "", "| file | bytes | sha256 |", "|---|---|---|"]
    for r in stats["sources"]:
        out.append("| %s | %d | %s |" % (r["file"], r["bytes"], r["sha256"]))
    out += ["", "## Licence", "",
            "The texts are in the public domain in the USA and are distributed by Project Gutenberg "
            "under the Project Gutenberg License; the files were taken from Gutenberg mirrors.", "",
            "## Processing", "",
            "Raw characters: %d. Pipeline: cleaning (header and footer, contents, illustration tags, "
            "unicode and whitespace, unwrapping), then one global filter and deduplication step, then a split by document." % stats["raw_chars"], "",
            "- paragraphs in: %d" % f["input"],
            "- removed as too short: %d" % f["too_short"],
            "- removed as low alpha: %d" % f["low_alpha"],
            "- removed as exact duplicates: %d" % f["exact_duplicates"],
            "- removed as near duplicates: %d" % f["near_duplicates"],
            "- kept: %d" % f["kept"], "",
            "## Splits", "", "| split | documents | characters | words | paragraphs |", "|---|---|---|---|---|"]
    for k in ("train", "val", "test"):
        out.append("| %s | %s | %d | %d | %d |" % (k, ", ".join(s[k]["documents"]), s[k]["chars"], s[k]["words"], s[k]["paragraphs"]))
    out += ["", "Against the training text: OOV rate val %.4f, test %.4f; 8-gram overlap val %.4f, test %.4f."
            % (lk["oov_val"], lk["oov_test"], lk["overlap_val"], lk["overlap_test"]), "",
            "## Statistics", "",
            "- total characters after cleaning: %d" % stats["clean_chars"],
            "- distinct characters: %d" % stats["distinct_chars"], "",
            "## Known limitations and biases", ""]
    out += ["- " + x for x in LIMITATIONS]
    return "\n".join(out) + "\n"
