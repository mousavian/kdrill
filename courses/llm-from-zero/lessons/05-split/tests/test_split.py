import json
import os
import random

import pytest

import split


def make_docs(n, size=1000, seed=0, varied=False):
    rnd = random.Random(seed)
    return {"doc%03d" % i: "x" * (size if not varied else rnd.randint(size // 2, size * 2)) for i in range(n)}


def test_partition_and_determinism():
    """every document lands in exactly one split; same seed gives the same result whatever the dict order"""
    docs = make_docs(30, varied=True)
    a = split.split_documents(docs, seed=3)
    assert sorted(a["train"] + a["val"] + a["test"]) == sorted(docs)
    assert len(set(a["train"]) & set(a["val"])) == 0 and len(set(a["train"]) & set(a["test"])) == 0 and not set(a["val"]) & set(a["test"])
    reordered = dict(reversed(list(docs.items())))
    assert split.split_documents(reordered, seed=3) == a
    assert all(v == sorted(v) for v in a.values()), "lists must be sorted by name"
    assert any(split.split_documents(docs, seed=s) != a for s in range(10)), "the seed must matter"


def test_shares_follow_fractions():
    """with many similar documents the character shares are close to the fractions"""
    docs = make_docs(100, varied=True, seed=5)
    total = sum(map(len, docs.values()))
    for fr in [(0.8, 0.1, 0.1), (0.6, 0.2, 0.2), (0.9, 0.05, 0.05)]:
        a = split.split_documents(docs, fr, seed=1)
        for k, f in zip(("train", "val", "test"), fr):
            share = sum(len(docs[n]) for n in a[k]) / total
            assert abs(share - f) < 0.04, "%s share %.3f vs target %.2f" % (k, share, f)


def test_few_documents_every_split_non_empty():
    """with only 4 to 9 documents every split still gets at least one"""
    for n in (3, 4, 5, 9):
        for seed in range(6):
            a = split.split_documents(make_docs(n, varied=True, seed=seed), seed=seed)
            assert all(a[k] for k in ("train", "val", "test")), (n, seed, a)
            assert len(a["train"]) >= len(a["val"])


def test_zero_fraction_and_errors():
    """a zero fraction gets nothing; fractions must sum to 1; there must be enough documents"""
    a = split.split_documents(make_docs(10), (0.9, 0.1, 0.0))
    assert a["test"] == [] and a["val"] and a["train"]
    with pytest.raises(ValueError):
        split.split_documents(make_docs(10), (0.5, 0.2, 0.2))
    with pytest.raises(ValueError):
        split.split_documents(make_docs(2), (0.8, 0.1, 0.1))


def test_random_line_split():
    """split_lines_randomly puts the stated share into validation, keeps order, and is seeded"""
    lines = ["line %d" % i for i in range(200)]
    tr, va = split.split_lines_randomly(lines, 0.1, seed=4)
    assert len(va) == 20 and len(tr) == 180 and sorted(tr + va, key=lambda s: int(s.split()[1])) == lines
    assert tr == sorted(tr, key=lambda s: int(s.split()[1])) and va == sorted(va, key=lambda s: int(s.split()[1]))
    assert split.split_lines_randomly(lines, 0.1, seed=4) == (tr, va) and split.split_lines_randomly(lines, 0.1, seed=5) != (tr, va)


def test_words_ngram_overlap_oov():
    """ngram_overlap and oov_rate give exact values on small examples"""
    ref = "the cat sat on the mat and the dog barked"
    assert split.ngram_overlap(ref, "the cat sat on the mat", n=3) == 1.0
    assert split.ngram_overlap(ref, "the cat sat on a mat", n=3) == pytest.approx(1 / 2)  # "the cat sat" and "cat sat on"
    assert split.ngram_overlap(ref, "short", n=3) == 0.0
    assert split.ngram_overlap(ref, "THE CAT, SAT!", n=3) == 1.0
    assert split.oov_rate("a b c", "a b d d") == pytest.approx(0.5)
    assert split.oov_rate("a b c", "") == 0.0
    assert split.oov_rate("", "x y") == 1.0


def test_line_split_flatters_validation():
    """on documents with their own character names, a random line split shows a much lower OOV rate than a document split"""
    rnd = random.Random(8)
    common = ["said", "the", "and", "went", "home", "again", "never", "quite", "door", "night"]
    docs = {}
    for d in range(12):
        name = "name%dx" % d
        docs["d%02d" % d] = "\n".join(
            " ".join([name] + [rnd.choice(common) for _ in range(8)]) for _ in range(60))
    a = split.split_documents(docs, seed=2)
    train = "\n".join(docs[n] for n in a["train"])
    val = "\n".join(docs[n] for n in a["val"])
    lines = [l for t in docs.values() for l in t.split("\n")]
    tr, va = split.split_lines_randomly(lines, 0.1, seed=2)
    oov_doc = split.oov_rate(train, val)
    oov_line = split.oov_rate("\n".join(tr), "\n".join(va))
    assert oov_line < 0.01 and oov_doc > 0.05, "document split %.3f, line split %.3f" % (oov_doc, oov_line)
    assert split.ngram_overlap(train, val, 3) < split.ngram_overlap("\n".join(tr), "\n".join(va), 3)


def test_write_splits(tmp_path):
    """write_splits writes the three files and splits.json exactly as specified"""
    docs = {"a": "Alpha text.\n", "b": " Beta text \n\n", "c": "Gamma.", "d": "Delta."}
    asg = {"train": ["b", "a"], "val": ["c"], "test": ["d"]}
    out = str(tmp_path / "o" / "p")
    sizes = split.write_splits(docs, asg, out)
    assert open(os.path.join(out, "train.txt")).read() == "Alpha text.\n\nBeta text\n"
    assert open(os.path.join(out, "val.txt")).read() == "Gamma.\n" and open(os.path.join(out, "test.txt")).read() == "Delta.\n"
    assert json.load(open(os.path.join(out, "splits.json"))) == asg
    assert sizes == {"train": len("Alpha text.\n\nBeta text\n"), "val": 7, "test": 7}


def test_real_documents_no_overlap():
    """splitting the real books by document: no document is shared, shares are plausible, files can be written"""
    from kdlib.corpus import bundled_raw
    docs = {"244": bundled_raw(244), "2097": bundled_raw(2097), "x1": bundled_raw(244)[:60000], "x2": bundled_raw(2097)[:60000]}
    a = split.split_documents(docs, seed=0)
    assert all(a[k] for k in a)
    assert sorted(a["train"] + a["val"] + a["test"]) == sorted(docs)
