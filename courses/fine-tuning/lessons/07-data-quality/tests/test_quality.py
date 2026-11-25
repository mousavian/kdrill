import json

import pytest

import quality as Q
from kdlib import kdtest, refimpl as I, tasks as T


@pytest.fixture(scope="module")
def facts():
    return T.FACTS


def test_no_libraries():
    """plain Python"""
    kdtest.assert_no_imports("quality", {"peft", "trl", "transformers", "pandas", "sklearn"})


def test_parse_question_on_all_questions():
    """every question of the task parses to its attribute and thing; near-misses and junk do not"""
    for attr, x, q, a in T._all():
        assert Q.parse_question(q) == (attr, x), q
    for bad in ["What colour is the ?", "what colour is the lamp?", "What colour is the lamp", "What colour is the lamp? ", "", "Where is the lamp?",
                "Name the colour of lamp.", "Tell me the colour of the lamp", "In which room is the?"]:
        assert Q.parse_question(bad) is None, repr(bad)
    assert Q.parse_question("What colour is the old lamp?") == ("colour", "old lamp")


def test_is_consistent_cases(facts):
    """consistent means: parses, known thing, answer exactly equal to the fact"""
    x = T.ENTITIES[3]
    col, room = facts["colour"][x], facts["room"][x]
    other = [c for c in T.COLOURS if c != col][0]
    ok = lambda q, a: Q.is_consistent({"question": q, "answer": a}, facts)
    assert ok("What colour is the %s?" % x, col) and ok("Where is the %s kept?" % x, room)
    assert not ok("What colour is the %s?" % x, other)
    assert not ok("What colour is the %s?" % x, room), "a room is not a colour"
    assert not ok("What colour is the %s?" % x, col + " "), "exact match: no stripping"
    assert not ok("What colour is the %s?" % x, col.upper())
    assert not ok("What colour is the unknownthing?", col) and not ok("Tell me about %s" % x, col)
    assert not Q.is_consistent({"question": "What colour is the %s?" % x}, facts)


def test_filter_separates_good_from_bad(facts):
    """on a fresh noisy file (seed 77) the filter drops exactly the wrong rows, keeps the rest in order and does not modify rows"""
    rows, flags = T.make_noisy_qa(n=300, noise=0.4, seed=77)
    snapshot = json.loads(json.dumps(rows))
    kept, dropped = Q.split_clean(rows, facts)
    assert kept == [r for r, f in zip(rows, flags) if f] and dropped == [r for r, f in zip(rows, flags) if not f]
    assert rows == snapshot
    assert Q.noise_rate(rows, facts) == pytest.approx(1 - sum(flags) / len(flags)) and Q.noise_rate([], facts) == 0.0


def test_bundled_noisy_file(facts):
    """the course's data/qa_noisy.jsonl: about a third of the rows are wrong, and the filter finds them all"""
    rows = T.read_jsonl("/kdlib/kdlib/data/qa_noisy.jsonl")
    kept, dropped = Q.split_clean(rows, facts)
    assert len(rows) == 300 and 0.25 < len(dropped) / 300 < 0.45
    assert all(T.expected_answer(r["question"]) == r["answer"] for r in kept)
    assert all(T.expected_answer(r["question"]) != r["answer"] for r in dropped)


def test_same_budget_clean_beats_noisy(facts):
    """250 steps on the noisy rows versus 250 steps on the validated ones: the validated model is at least 0.1 better in exact match"""
    m, tok = I.ref_base()
    ev = T.read_jsonl("/kdlib/kdlib/data/qa_eval.jsonl")[:50]
    rows, _ = T.make_noisy_qa(n=300, noise=0.35, seed=77)
    kept, _ = Q.split_clean(rows, facts)
    res = {}
    for name, data in (("noisy", rows), ("clean", kept)):
        mm = I.clone(m)
        I.sft_train(mm, I.qa_items(tok, data), 250, 2e-3, seed=0, pad=0)
        res[name] = I.qa_eval(mm, tok, ev)["exact"]
    assert res["clean"] >= res["noisy"] + 0.1, "exact match: noisy %.2f, validated %.2f" % (res["noisy"], res["clean"])
