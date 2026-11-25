import math

import pytest

import sweep
import trust as U
from kdlib import kdtest, refimpl as I, tasks as T


def test_no_libraries():
    """pure Python: no numpy, scipy, pandas, statistics"""
    kdtest.assert_no_imports("trust", {"numpy", "scipy", "pandas", "statistics", "sklearn"})


def test_words_and_ngrams():
    """words are lower-case alphanumerics with apostrophes; n-grams are tuples; a short text counts as one whole gram"""
    assert U.words("The Dog's bone, 2 times!") == ["the", "dog's", "bone", "2", "times"]
    assert U.ngrams("a b c d", 2) == {("a", "b"), ("b", "c"), ("c", "d")}
    assert U.ngrams("a b", 3) == {("a", "b")} and U.ngrams("", 3) == set() and U.ngrams("!!!", 2) == set()
    assert U.build_index(["a b c", "b c d"], 2) == {("a", "b"), ("b", "c"), ("c", "d")}


def test_contamination_flags_planted_copies():
    """eval texts that share an n-gram with the training texts are flagged; unrelated ones are not; the case and punctuation do not hide a copy"""
    train = ["The quick brown fox jumps over the lazy dog near the old river bank.", "Nothing to see here at all, only some plain words today."]
    ev = ["Then THE quick brown fox jumps over the lazy dog, said she.", "A completely different sentence about trains and weather in spring.",
          "only some plain words today"]
    assert U.contaminated(ev, train, n=5) == [True, False, True]
    assert U.contaminated(ev, train, n=8) == [True, False, False]
    assert U.contaminated([], train) == []


def test_overlap_rate_counts_every_occurrence():
    """the overlap rate is hits over all the eval n-grams, with repeats counted; 0.0 when there are none"""
    train = ["a b c d e"]
    ev = ["a b c x", "a b c"]            # bigrams: ab bc cx | ab bc  -> 4 of 5 are in train
    assert U.overlap_rate(ev, train, n=2) == pytest.approx(4 / 5)
    assert U.overlap_rate(["x y z"], train, n=2) == 0.0 and U.overlap_rate([], train, n=2) == 0.0 and U.overlap_rate(["!!"], train, n=2) == 0.0
    assert U.overlap_rate(["a b"], ["a b"], n=5) == 1.0, "a short text counts as one whole gram"


def test_decontaminate_on_the_course_data():
    """the real files: held-out questions do not occur in the training questions; five planted copies are found and removed in order, the eval rows are untouched"""
    tr, ev = T.read_jsonl("/kdlib/kdlib/data/qa_train.jsonl"), T.read_jsonl("/kdlib/kdlib/data/qa_eval.jsonl")
    assert not any(U.contaminated([e["question"] for e in ev], [r["question"] for r in tr], n=8)), "the course's data must be clean"
    planted = tr[:10] + ev[:5] + tr[10:20]
    snap = [dict(e) for e in ev]
    kept, removed = U.decontaminate(planted, ev, n=8)
    assert removed == ev[:5] and kept == tr[:10] + tr[10:20] and ev == snap
    kept, removed = U.decontaminate([{"text": "a b c d e f g h i"}, {"text": "x y"}], [{"text": "q a b c d e f g h r"}], n=8, field="text")
    assert [r["text"] for r in removed] == ["a b c d e f g h i"] and len(kept) == 1


def test_real_text_overlap_is_small_but_planting_shows():
    """8-gram overlap between the Alice training chapters and the later chapters is tiny; adding two training paragraphs to the evaluation text is caught"""
    tr = [p for p in T.alice("train").split("\n\n") if p.strip()]
    ev = [p for p in T.alice("val").split("\n\n") if p.strip()]
    base_rate = U.overlap_rate(ev, tr, 8)
    assert base_rate < 0.03
    flags = U.contaminated(ev + [tr[5], tr[40]], tr, 8)
    assert flags[-2:] == [True, True] and sum(flags[:-2]) <= 3


def test_mean_std_and_intervals():
    """sample standard deviation (n - 1), t-based half-widths from the table, infinite for one value"""
    assert U.mean_std([2.0, 4.0, 6.0]) == (4.0, pytest.approx(2.0)) and U.mean_std([5.0]) == (5.0, 0.0)
    m, h = U.ci95([1.0, 2.0, 3.0, 4.0])
    assert m == 2.5 and h == pytest.approx(3.182 * math.sqrt(5 / 3) / 2, rel=1e-3)
    assert U.ci95([1.0])[1] == float("inf")
    vals = [float(i % 5) for i in range(100)]
    assert U.ci95(vals)[1] == pytest.approx(1.96 * U.mean_std(vals)[1] / 10)
    v13 = [float(i) for i in range(13)]       # df 12: in the table
    assert U.ci95(v13)[1] == pytest.approx(2.179 * U.mean_std(v13)[1] / math.sqrt(13))
    v14 = [float(i) for i in range(14)]       # df 13: not in the table, use the entry for 12
    assert U.ci95(v14)[1] == pytest.approx(2.179 * U.mean_std(v14)[1] / math.sqrt(14))


def test_paired_summary_and_binomial():
    """the paired difference uses the per-seed differences: a consistent small gain is real, a large but noisy one may not be"""
    a = [0.50, 0.40, 0.60, 0.30]
    b = [0.52, 0.42, 0.62, 0.32]                       # +0.02 every seed: the spread of the seeds does not matter
    s = U.paired_summary(a, b)
    assert s["diff"] == pytest.approx(0.02) and s["ci"] < 1e-9 and s["b_better"] is True
    assert s["mean_a"] == pytest.approx(0.45) and s["std_a"] == pytest.approx(U.mean_std(a)[1]) and s["std_b"] == pytest.approx(U.mean_std(b)[1])
    c = [0.62, 0.22, 0.72, 0.37]                       # mean +0.05 but wildly different per seed
    s2 = U.paired_summary(a, c)
    assert s2["diff"] > 0.02 and s2["b_better"] is False
    with pytest.raises(ValueError):
        U.paired_summary([1, 2], [1, 2, 3])
    assert U.binomial_se(0.5, 100) == pytest.approx(0.05) and U.binomial_se(0.55, 400) == pytest.approx(math.sqrt(0.55 * 0.45 / 400))
    assert U.binomial_se(1.0, 10) == 0.0


def test_seeds_move_the_numbers_and_the_summary_sees_it():
    """real runs: LoRA style loss over three seeds varies a little (your std is above zero), and rank 8 beats rank 2 by more than the noise"""
    m, tok = I.ref_base()
    tr, va = I.ids_of(tok, T.alice("train")), I.ids_of(tok, T.alice("val"))[:3000]
    seeds = [0, 1, 2]
    low = [-sweep.lora_run(m, tr, va, 1, 2, steps=60, seed=s)["val_loss"] for s in seeds]
    high = [-sweep.lora_run(m, tr, va, 8, 16, steps=60, seed=s)["val_loss"] for s in seeds]
    assert len(set(low)) == 3, "different seeds must give different runs (seed the adapter and the batches)"
    s = U.paired_summary(low, high)
    assert s["std_a"] > 0 and s["diff"] > 0.05 and s["b_better"], s
