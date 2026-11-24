import json
import re
import time

import pytest

import vocab_study as vs
from bpe import BPE
from kdlib.corpus import bundled_splits


def test_simple_metrics():
    """tokens_per_word, bytes_per_token and embedding_params on tiny examples (including empty input)"""
    assert vs.tokens_per_word([1] * 6, "a b c") == 2.0 and vs.tokens_per_word([1], "") == 0.0
    assert vs.bytes_per_token([1, 2], "caf\u00e9") == 2.5 and vs.bytes_per_token([], "abc") == 0.0
    assert vs.embedding_params(1000, 64) == 64000


def test_rare_fraction():
    """rare_fraction counts only learned merge tokens used fewer than min_count times"""
    t = BPE([(97, 98), (256, 99), (100, 101)], ())      # ids 256, 257, 258
    ids = [97, 98, 256, 256, 256, 257, 257, 1, 2, 3, 258]   # 256 x3, 257 x2, 258 x1; byte ids ignored
    assert vs.rare_fraction(t, ids, min_count=2) == pytest.approx(1 / 3)
    assert vs.rare_fraction(t, ids, min_count=3) == pytest.approx(2 / 3)
    assert vs.rare_fraction(t, ids, min_count=100) == 1.0 and vs.rare_fraction(t, ids, min_count=1) == 0.0
    assert vs.rare_fraction(BPE([], ()), [1, 2, 3]) == 0.0


def test_study_matches_separate_training():
    """one training run gives every smaller size: rows equal what training that size alone would measure"""
    tr, va, _ = bundled_splits()
    tr, va = tr[:40000], va[:8000]
    sizes = [257, 300, 400]
    rows = vs.study(tr, va, sizes)
    assert [r["merges"] for r in rows] == [0, 43, 143]
    assert set(rows[0]) == {"vocab_size", "merges", "tokens_per_word", "bytes_per_token", "rare_fraction"}
    for r in rows[:2]:
        t = BPE.train(tr, r["merges"], vs.SPECIALS)
        ids = t.encode(va)
        assert r["vocab_size"] == t.vocab_size
        assert r["tokens_per_word"] == pytest.approx(len(ids) / len(va.split()))
        assert r["bytes_per_token"] == pytest.approx(len(va.encode()) / len(ids))
        assert r["rare_fraction"] == pytest.approx(vs.rare_fraction(t, ids))
    assert rows[0]["rare_fraction"] == 0.0 and rows[0]["bytes_per_token"] == 1.0


def test_trends_and_speed():
    """more merges: fewer tokens per word, more bytes per token, more rarely used tokens; and it is fast"""
    tr, va, _ = bundled_splits()
    t0 = time.time()
    rows = vs.study(tr[:60000], va[:10000], [260, 300, 400, 600, 800])
    assert time.time() - t0 < 30, "train once, then slice the merges"
    tpw = [r["tokens_per_word"] for r in rows]
    bpt = [r["bytes_per_token"] for r in rows]
    assert all(a > b for a, b in zip(tpw, tpw[1:])) and all(a < b for a, b in zip(bpt, bpt[1:]))
    assert rows[-1]["rare_fraction"] > rows[0]["rare_fraction"]


def test_choose_size():
    """choose_size returns the largest size within the rare budget, else the smallest size"""
    rows = [{"vocab_size": s, "rare_fraction": r} for s, r in [(300, 0.0), (600, 0.1), (1000, 0.2), (2000, 0.4)]]
    assert vs.choose_size(rows, 0.25) == 1000 and vs.choose_size(rows, 0.05) == 300 and vs.choose_size(rows, 1.0) == 2000
    assert vs.choose_size([{"vocab_size": 500, "rare_fraction": 0.9}, {"vocab_size": 700, "rare_fraction": 0.95}], 0.1) == 500


def test_your_choice_is_justified_with_numbers():
    """vocab_choice.json holds your integer choice (257-20000) and a reason of 80+ characters that cites at least three numbers"""
    d = json.load(open("vocab_choice.json"))
    assert isinstance(d.get("vocab_size"), int) and 257 <= d["vocab_size"] <= 20000, "write your chosen vocab_size"
    reason = d.get("reason", "")
    assert len(reason) >= 80 and "TODO" not in reason, "explain your choice"
    assert len(re.findall(r"\d+(?:\.\d+)?", reason)) >= 3, "back the choice with numbers from the study"
