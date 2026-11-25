import json
import re

import pytest

import sft_data as S
from kdlib import kdtest, refimpl as I, tasks as T


@pytest.fixture(scope="module")
def tok():
    return I.ref_base()[1]


def test_clean_text_and_template():
    """clean_text collapses whitespace; the template is 'Q: <question>\\nA:' + ' <answer>' + end-of-text"""
    assert S.clean_text("  a \t b\n\n c  ") == "a b c" and S.clean_text("   ") == ""
    p, c = S.format_example("What colour is the lamp?", "grey")
    assert p == "Q: What colour is the lamp?\nA:" and c == " grey<|endoftext|>"


def test_clean_examples_on_a_fresh_messy_file():
    """on a newly generated raw file (seed 99) the cleaning keeps exactly the valid unique questions, once each, cleaned"""
    rows, truth = T.make_raw_qa(seed=99)
    out = S.clean_examples(rows)
    got = [e["question"] for e in out]
    assert len(got) == len(set(got)), "a question survived twice"
    assert set(got) == truth, "kept %d, expected %d; missing %s; unexpected %s" % (
        len(got), len(truth), sorted(truth - set(got))[:2], sorted(set(got) - truth)[:2])
    for e in out:
        assert e["answer"] == T.expected_answer(e["question"]), e
        assert "  " not in e["question"] and e["answer"] == e["answer"].strip()
    first = {}
    for r in rows:
        first.setdefault(S.clean_text(r["question"]), len(first))
    assert [e["question"] for e in out] == sorted(got, key=lambda q: first[q]), "keep the order of first occurrence"


def test_clean_examples_rules_one_by_one():
    """each rule on its own: marker, newline, empty fields, length limit, first duplicate wins, input untouched"""
    rows = [{"question": "q1", "answer": "a1"}, {"question": "q2", "answer": "a<|endoftext|>"}, {"question": "q3", "answer": "a\nb"},
            {"question": "q4\nx", "answer": "a"}, {"question": " ", "answer": "a"}, {"question": "q5", "answer": "  "},
            {"question": "word " * 15, "answer": "b " * 6}, {"question": " q1 ", "answer": "other"}, {"question": "q6", "answer": " a  b "}]
    copy = json.loads(json.dumps(rows))
    out = S.clean_examples(rows, max_words=20)
    assert out == [{"question": "q1", "answer": "a1"}, {"question": "q6", "answer": "a b"}], out
    assert rows == copy, "the input rows must not be modified"
    assert len(S.clean_examples(rows, max_words=100)) == 3        # the long row is kept when the limit allows it


def test_split_has_no_leakage():
    """train and eval are disjoint and complete, reproducible for a seed, different for another, and keep the original order"""
    ex = [{"question": "q%d" % i, "answer": "a"} for i in range(50)]
    tr, ev = S.split_examples(ex, 0.2, seed=1)
    assert len(ev) == 10 and len(tr) == 40
    assert not {e["question"] for e in tr} & {e["question"] for e in ev}
    assert sorted(e["question"] for e in tr + ev) == sorted(e["question"] for e in ex)
    for side in (tr, ev):
        idx = [int(e["question"][1:]) for e in side]
        assert idx == sorted(idx)
    assert S.split_examples(ex, 0.2, seed=1) == (tr, ev) and S.split_examples(ex, 0.2, seed=2)[1] != ev
    assert len(S.split_examples(ex[:3], 0.01)[1]) == 1, "at least one eval example"


def test_split_rejects_duplicates_and_bad_fractions():
    """duplicates would leak across the split: refuse them; the fraction must be strictly between 0 and 1"""
    ex = [{"question": "q", "answer": "a"}, {"question": "q", "answer": "b"}, {"question": "r", "answer": "c"}]
    with pytest.raises(ValueError):
        S.split_examples(ex, 0.3)
    for f in (0, 1, -0.2, 1.5):
        with pytest.raises(ValueError):
            S.split_examples(ex[1:], f)


def test_encoding_boundary_and_eos(tok):
    """ids = prompt ids + completion ids, equal to encoding the whole string at once, ending with the end-of-text id"""
    eos = tok.special_ids[S.EOS]
    for e in T.all_questions()[::37]:
        ids, pl = S.encode_example(tok, e["question"], e["answer"])
        p, c = S.format_example(e["question"], e["answer"])
        assert ids == tok.encode(p + c), "splitting prompt and completion changed the tokens"
        assert ids[-1] == eos and ids.count(eos) == 1 and ids[:pl] == tok.encode(p) and pl < len(ids) - 1
        assert tok.decode(ids[pl:-1]) == " " + e["answer"]


def test_encode_all_and_stats(tok):
    """encode_all drops what does not fit the context and counts it; dataset_stats reports lengths and the answer share"""
    ex = T.all_questions()[:20] + [{"question": "word " * 30, "answer": "x"}]
    items, dropped = S.encode_all(tok, ex, 48)
    assert dropped == 1 and len(items) == 20 and all(len(i) <= 48 for i, _ in items)
    st = S.dataset_stats(items)
    tot = sum(len(i) for i, _ in items)
    assert st["n"] == 20 and st["mean_len"] == pytest.approx(tot / 20) and st["max_len"] == max(len(i) for i, _ in items)
    assert st["answer_share"] == pytest.approx(sum(len(i) - p for i, p in items) / tot) and 0.05 < st["answer_share"] < 0.5


def test_no_libraries():
    """plain Python and PyTorch"""
    kdtest.assert_no_imports("sft_data", {"peft", "trl", "transformers", "datasets", "sklearn", "pandas"})
