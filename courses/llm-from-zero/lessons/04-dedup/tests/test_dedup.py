import random
import re
import time

import pytest

import dedup

WORDS = ["".join(chr(97 + (i // 26 ** j) % 26) for j in range(4)) for i in range(3000)]


def rpara(rnd, n=40):
    return " ".join(rnd.choice(WORDS) for _ in range(n)) + "."


def ref_shingles(par, k):
    w = re.findall(r"\w+", par.lower())
    if not w:
        return set()
    return {" ".join(w[i:i + k]) for i in range(max(1, len(w) - k + 1))}


def ref_jaccard(a, b):
    return len(a & b) / len(a | b) if (a | b) else 0.0


def test_paragraphs():
    """paragraphs splits on blank lines (even ones holding spaces), strips, and drops empties"""
    t = "  one\ntwo \n\n\n   \t\nthree\n\n\n"
    assert dedup.paragraphs(t) == ["one\ntwo", "three"]
    assert dedup.paragraphs("") == [] and dedup.paragraphs("\n\n") == []


def test_norm_key_and_exact_dedup():
    """paragraphs that differ only in case, punctuation or spacing are exact duplicates; the first one is kept"""
    assert dedup.norm_key("Hello,  World!") == dedup.norm_key("hello world") == "helloworld"
    paras = ["The game is afoot.", "Another one entirely.", "the GAME is afoot!!", "The  game  is afoot", "Another one entirely."]
    kept, n = dedup.exact_dedup(paras)
    assert kept == ["The game is afoot.", "Another one entirely."] and n == 3


def test_exact_dedup_stores_hashes():
    """exact_dedup works on very long paragraphs without keeping them (hashes), and keeps order"""
    big = "x" * 2_000_000
    kept, n = dedup.exact_dedup([big, "a", big + "", "b", "a"])
    assert kept == [big, "a", "b"] and n == 2


def test_shingles_and_jaccard():
    """shingles are word k-grams (short texts give one shingle); jaccard is |A&B|/|A|B|"""
    assert dedup.shingles("The quick brown fox jumps", k=3) == {"the quick brown", "quick brown fox", "brown fox jumps"}
    assert dedup.shingles("Hi there", k=5) == {"hi there"}
    assert dedup.shingles("... !!", k=2) == set()
    assert dedup.shingles("a b c d e f", k=5) == {"a b c d e", "b c d e f"}
    assert dedup.jaccard({1, 2, 3}, {2, 3, 4}) == pytest.approx(0.5)
    assert dedup.jaccard(set(), set()) == 0.0 and dedup.jaccard({1}, set()) == 0.0
    assert dedup.jaccard({"a"}, {"a"}) == 1.0


def test_near_dedup_threshold_and_report():
    """a paragraph with one changed word is a near-duplicate at a low threshold only; unrelated ones stay"""
    rnd = random.Random(1)
    a = rpara(rnd)
    words = a.split()
    words[20] = "CHANGED"
    b = " ".join(words)
    c = rpara(rnd)
    sim = ref_jaccard(ref_shingles(a, 5), ref_shingles(b, 5))
    assert 0.6 < sim < 0.9
    kept, dropped = dedup.near_dedup([a, c, b], threshold=sim - 0.01, k=5)
    assert kept == [a, c]
    assert len(dropped) == 1 and dropped[0][0] == 2 and dropped[0][1] == 0 and dropped[0][2] == pytest.approx(sim)
    kept2, dropped2 = dedup.near_dedup([a, c, b], threshold=sim + 0.01, k=5)
    assert kept2 == [a, c, b] and dropped2 == []


def test_near_dedup_earlier_wins_and_chains():
    """the earlier paragraph wins even when the later one is longer; a chain A~B~C keeps C if C is far from A"""
    rnd = random.Random(2)
    base = [rnd.choice(WORDS) for _ in range(60)]
    a = " ".join(base[:40])
    longer = " ".join(base[:40] + base[40:44])   # contains all of a
    kept, dropped = dedup.near_dedup([a, longer], threshold=0.8, k=3)
    assert kept == [a] and dropped[0][:2] == (1, 0)
    kept, dropped = dedup.near_dedup([longer, a], threshold=0.8, k=3)
    assert kept == [longer] and dropped[0][:2] == (1, 0)
    # chain: each step changes a sixth of the words
    w = [rnd.choice(WORDS) for _ in range(48)]
    A = " ".join(w)
    w2 = w[:]; w2[::6] = ["x%d" % i for i in range(8)]
    B = " ".join(w2)
    w3 = w2[:]; w3[3::6] = ["y%d" % i for i in range(8)]
    C = " ".join(w3)
    sAB = ref_jaccard(ref_shingles(A, 2), ref_shingles(B, 2)); sBC = ref_jaccard(ref_shingles(B, 2), ref_shingles(C, 2))
    sAC = ref_jaccard(ref_shingles(A, 2), ref_shingles(C, 2))
    thr = min(sAB, sBC) - 0.01
    assert sAC < thr, "test setup"
    kept, dropped = dedup.near_dedup([A, B, C], threshold=thr, k=2)
    assert kept == [A, C] and [d[0] for d in dropped] == [1], "compare with KEPT paragraphs only"


def test_near_dedup_picks_most_similar_match():
    """when several kept paragraphs match, the most similar one is reported"""
    rnd = random.Random(3)
    w = [rnd.choice(WORDS) for _ in range(50)]
    p0 = " ".join(w)
    w1 = w[:]; w1[::4] = ["q%d" % i for i in range(13)]
    p1 = " ".join(w1)  # different enough from p0 to be kept at 0.9
    w2 = w1[:]; w2[1] = "tiny"
    p2 = " ".join(w2)  # very close to p1, further from p0
    kept, dropped = dedup.near_dedup([p0, p1, p2], threshold=0.5, k=2)
    # p1 matches p0 at threshold 0.5? whichever happens, p2 must name the more similar kept paragraph
    best = max(((ref_jaccard(ref_shingles(p2, 2), ref_shingles(x, 2)), -i) for i, x in enumerate([p0, p1]) if x in kept), default=None)
    if len(kept) == 2:
        assert dropped[0][0] == 2 and dropped[0][1] == -best[1]


def test_near_dedup_scales():
    """4000 paragraphs, 400 of them near-copies, are processed in a few seconds (use an inverted index)"""
    rnd = random.Random(4)
    paras = [rpara(rnd, 45) for _ in range(3600)]
    for i in range(400):
        w = paras[rnd.randrange(3600)].split()
        w[rnd.randrange(len(w))] = "tweak%d" % i
        paras.append(" ".join(w))
    rnd.shuffle(paras)
    t0 = time.time()
    kept, dropped = dedup.near_dedup(paras, threshold=0.7, k=3)
    dt = time.time() - t0
    assert len(dropped) == 400, "expected the 400 planted near-copies, got %d" % len(dropped)
    assert dt < 25, "took %.1f s: comparing every pair does not scale" % dt


def test_junk_reason():
    """junk_reason: too short, mostly symbols, or fine (None); thresholds are parameters"""
    assert dedup.junk_reason("short") == "too_short"
    assert dedup.junk_reason("* * * * * * * * * * * * * * * *") == "low_alpha"
    assert dedup.junk_reason("A perfectly normal sentence about a violin.") is None
    assert dedup.junk_reason("short", min_chars=3) is None
    assert dedup.junk_reason("1234567890 abc 1234567890", min_alpha=0.1) is None
    assert dedup.junk_reason("") == "too_short"


def test_filter_and_dedup_counts():
    """the whole step on a corpus with planted junk and duplicates: exact counts, in the right order"""
    rnd = random.Random(5)
    uniq = [rpara(rnd) for _ in range(60)]
    exact = [uniq[i].upper() for i in range(10)]
    near = []
    for i in range(10, 18):
        w = uniq[i].split(); w[5] = "edited"; near.append(" ".join(w))
    short = ["ok.", "Hi", "No."]
    symbols = ["-- -- -- -- -- -- -- -- -- -- --", "1234 5678 9012 3456 7890 1234 5678"]
    paras = uniq + exact + near + short + symbols
    rnd.shuffle(paras)
    kept, st = dedup.filter_and_dedup(paras, min_chars=15, min_alpha=0.6, threshold=0.7, k=3)
    assert st == {"input": len(paras), "too_short": 3, "low_alpha": 2, "exact_duplicates": 10, "near_duplicates": 8, "kept": 60}, st
    assert len(kept) == 60
    assert sum(v for k, v in st.items() if k != "input") == st["input"]


def test_filter_stats_attribute_each_paragraph_once():
    """a short duplicate counts as junk (junk runs first), an exact copy is never also counted as near"""
    p = "This is one reasonably long paragraph about a hansom cab."
    kept, st = dedup.filter_and_dedup(["ok", "ok", p, p, p.lower()], min_chars=15, threshold=0.5, k=3)
    assert st["too_short"] == 2 and st["exact_duplicates"] == 2 and st["near_duplicates"] == 0 and st["kept"] == 1


def test_real_corpus_filters():
    """on the real corpus the step runs, removes only a minority and loses no story paragraph by accident"""
    import os
    from kdlib.corpus import bundled_raw
    try:
        import clean
        text = clean.clean_book(bundled_raw(244))
    except Exception:
        text = bundled_raw(244)
    paras = dedup.paragraphs(text)
    kept, st = dedup.filter_and_dedup(paras)
    assert st["input"] == len(paras) and st["kept"] == len(kept)
    assert 0.5 * len(paras) < len(kept) <= len(paras)
    assert any("Sherlock Holmes" in p for p in kept)
