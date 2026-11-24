import hashlib
import json
import os
import random

import pytest

import prepare

WORDS = ["".join(chr(97 + (i // 26 ** j) % 26) for j in range(4)) for i in range(4000)]


def para(rnd, n=60):
    w = [rnd.choice(WORDS) for _ in range(n)]
    out, line = [], []
    for x in w:  # hard-wrap at ~60 columns like Gutenberg
        line.append(x)
        if len(" ".join(line)) > 60:
            out.append(" ".join(line)); line = []
    if line:
        out.append(" ".join(line))
    return "\n".join(out)


def make_raw(tmp_path):
    rnd = random.Random(21)
    shared = para(rnd)               # appears in book 1 and book 4: one exact duplicate
    near_base = para(rnd)
    w = near_base.replace("\n", " ").split()
    w[30] = "changedword"
    near_copy = " ".join(w)          # book 3 has a one-word variant of book 2's paragraph
    raw = tmp_path / "raw"
    raw.mkdir()
    for b in range(1, 7):
        paras = ["BOOK %d" % b, "Chapter 1.", "* * * * * * * * * * * * * *"]   # three too_short (BOOK n, Chapter 1., THE END), one low_alpha per book
        paras += [para(rnd) for _ in range(25)]
        if b in (1, 4):
            paras.insert(6, shared)
        if b == 2:
            paras.insert(7, near_base)
        if b == 3:
            paras.insert(7, near_copy)
        paras.append("THE END")
        body = "\r\n\r\n".join(p.replace("\n", "\r\n") for p in paras)
        text = ("\ufeffThe Project Gutenberg eBook of Book %d\r\n\r\nLicence blurb here.\r\n\r\n"
                "*** START OF THE PROJECT GUTENBERG EBOOK BOOK %d ***\r\n\r\n%s\r\n\r\n"
                "*** END OF THE PROJECT GUTENBERG EBOOK BOOK %d ***\r\nMore licence.\r\n") % (b, b, body, b)
        (raw / ("b%d.txt" % b)).write_bytes(text.encode("utf-8"))
    (raw / "manifest.json").write_text("{}")
    (raw / "notes.md").write_text("ignore me")
    return str(raw)


@pytest.fixture()
def built(tmp_path):
    raw = make_raw(tmp_path)
    before = {n: open(os.path.join(raw, n), "rb").read() for n in os.listdir(raw)}
    out = str(tmp_path / "out")
    stats = prepare.build_dataset(raw, out, seed=1)
    return raw, out, stats, before


def paras_of(text):
    return [p.strip() for p in text.split("\n\n") if p.strip()]


def test_files_and_split_by_document(built):
    """train/val/test/splits.json/DATA_CARD.md exist; every book is in exactly one split; raw files untouched"""
    raw, out, stats, before = built
    for f in ("train.txt", "val.txt", "test.txt", "splits.json", "DATA_CARD.md"):
        assert os.path.getsize(os.path.join(out, f)) > 0, f + " missing or empty"
    asg = json.load(open(os.path.join(out, "splits.json")))
    names = sorted(asg["train"] + asg["val"] + asg["test"])
    assert names == ["b%d.txt" % i for i in range(1, 7)], names
    assert all(asg[k] for k in asg)
    assert {n: open(os.path.join(raw, n), "rb").read() for n in os.listdir(raw)} == before, "raw files were modified"
    assert {k: v["documents"] for k, v in stats["splits"].items()} == asg


def test_cleaned_and_no_leakage(built):
    """no Gutenberg boilerplate or CR/BOM in the files, and no paragraph appears in two splits"""
    _, out, _, _ = built
    texts = {k: open(os.path.join(out, k + ".txt"), encoding="utf-8").read() for k in ("train", "val", "test")}
    for k, t in texts.items():
        assert "gutenberg" not in t.lower() and "licence" not in t.lower() and "\r" not in t and "\ufeff" not in t, k
        assert t.endswith("\n") and not t.endswith("\n\n")
    sets = {k: set(paras_of(t)) for k, t in texts.items()}
    assert not sets["train"] & sets["val"] and not sets["train"] & sets["test"] and not sets["val"] & sets["test"]
    allp = [p for t in texts.values() for p in paras_of(t)]
    assert len(allp) == len(set(allp)), "duplicate paragraphs survived"


def test_stats_are_correct(built):
    """the filter counts match the planted junk and duplicates, and every other number matches the written files"""
    raw, out, stats, _ = built
    f = stats["filters"]
    assert f["too_short"] == 18 and f["low_alpha"] == 6, f
    assert f["exact_duplicates"] == 1 and f["near_duplicates"] == 1, f
    assert f["input"] == f["too_short"] + f["low_alpha"] + f["exact_duplicates"] + f["near_duplicates"] + f["kept"]
    n_paras = 0
    for k in ("train", "val", "test"):
        t = open(os.path.join(out, k + ".txt"), encoding="utf-8").read()
        s = stats["splits"][k]
        assert s["chars"] == len(t) and s["words"] == len(t.split()) and s["paragraphs"] == len(paras_of(t)), k
        n_paras += s["paragraphs"]
    assert n_paras == f["kept"]
    assert stats["clean_chars"] == sum(stats["splits"][k]["chars"] for k in stats["splits"])
    alltext = "".join(open(os.path.join(out, k + ".txt"), encoding="utf-8").read() for k in ("train", "val", "test"))
    assert stats["distinct_chars"] == len(set(alltext))
    rawfiles = sorted(n for n in os.listdir(raw) if n.endswith(".txt"))
    assert [s["file"] for s in stats["sources"]] == rawfiles
    for s in stats["sources"]:
        data = open(os.path.join(raw, s["file"]), "rb").read()
        assert s["bytes"] == len(data) and s["sha256"] == hashlib.sha256(data).hexdigest()
    assert stats["raw_chars"] == sum(len(open(os.path.join(raw, n), encoding="utf-8").read()) for n in rawfiles)
    assert set(stats["leakage"]) == {"oov_val", "oov_test", "overlap_val", "overlap_test"}
    assert 0 <= stats["leakage"]["overlap_val"] < 0.2


def test_deterministic(tmp_path):
    """the same raw files and seed give byte-identical output; another seed may split differently"""
    raw = make_raw(tmp_path)
    a, b = str(tmp_path / "a"), str(tmp_path / "b")
    prepare.build_dataset(raw, a, seed=2)
    prepare.build_dataset(raw, b, seed=2)
    for f in ("train.txt", "val.txt", "test.txt", "splits.json", "DATA_CARD.md"):
        assert open(os.path.join(a, f), "rb").read() == open(os.path.join(b, f), "rb").read(), f
    outs = set()
    for seed in range(8):
        d = str(tmp_path / ("s%d" % seed))
        prepare.build_dataset(raw, d, seed=seed)
        outs.add(open(os.path.join(d, "splits.json")).read())
    assert len(outs) > 1, "the seed has no effect on the split"


def test_data_card(built):
    """the card has the required sections in order, and carries the checksums and numbers of this build"""
    raw, out, stats, _ = built
    card = open(os.path.join(out, "DATA_CARD.md"), encoding="utf-8").read()
    heads = ["# Data card", "## Sources", "## Licence", "## Processing", "## Splits", "## Statistics",
             "## Known limitations and biases"]
    pos = [card.find("\n" + h + "\n") if i else card.find(h) for i, h in enumerate(heads)]
    assert all(p >= 0 for p in pos), "missing section: %s" % [h for h, p in zip(heads, pos) if p < 0]
    assert pos == sorted(pos), "sections are in the wrong order"
    for s in stats["sources"]:
        assert s["file"] in card and s["sha256"] in card and str(s["bytes"]) in card
    low = card.lower()
    assert "public domain" in low and "gutenberg" in low
    f = stats["filters"]
    for key in ("input", "too_short", "low_alpha", "exact_duplicates", "near_duplicates", "kept"):
        assert str(f[key]) in card, key
    for k, v in stats["splits"].items():
        for key in ("chars", "words", "paragraphs"):
            assert str(v[key]) in card, (k, key)
    for n in (stats["raw_chars"], stats["clean_chars"], stats["distinct_chars"]):
        assert str(n) in card
    for v in stats["leakage"].values():
        assert any(("%.*f" % (d, v)) in card for d in (2, 3, 4, 5, 6)), "leakage value %r missing" % v
    for k, v in stats["splits"].items():
        for d in v["documents"]:
            assert d in card


def test_limitations_are_written_by_you():
    """LIMITATIONS has at least 3 real bullets of 40+ characters, no placeholders, and appear in the card"""
    lim = prepare.LIMITATIONS
    assert len(lim) >= 3, "write at least three limitations"
    for x in lim:
        assert len(x.strip()) >= 40 and "TODO" not in x, "write a real limitation, not %r" % x[:40]
    assert len(set(lim)) == len(lim)
    card = prepare.make_card({
        "sources": [], "raw_chars": 1, "filters": {"input": 1, "too_short": 0, "low_alpha": 0, "exact_duplicates": 0, "near_duplicates": 0, "kept": 1},
        "splits": {k: {"documents": ["d"], "chars": 1, "words": 1, "paragraphs": 1} for k in ("train", "val", "test")},
        "clean_chars": 3, "distinct_chars": 5,
        "leakage": {"oov_val": 0.5, "oov_test": 0.25, "overlap_val": 0.0, "overlap_test": 0.125}})
    tail = card.split("## Known limitations and biases")[1]
    for x in lim:
        assert "- " + x in tail


def test_real_corpus_builds(tmp_path):
    """the pipeline also runs on real Gutenberg files (the bundled books) and produces sensible splits"""
    from kdlib.corpus import bundled_raw
    raw = tmp_path / "raw"
    raw.mkdir()
    for i in (244, 2097):
        (raw / ("%d.txt" % i)).write_text(bundled_raw(i), encoding="utf-8")
    (raw / "x_part.txt").write_text(bundled_raw(244)[20000:90000], encoding="utf-8")
    stats = prepare.build_dataset(str(raw), str(tmp_path / "o"), seed=0)
    assert stats["filters"]["kept"] > 1000
    assert stats["splits"]["train"]["chars"] > stats["splits"]["val"]["chars"]
    assert stats["filters"]["exact_duplicates"] + stats["filters"]["near_duplicates"] > 0, "the partial copy of a book should be removed"
