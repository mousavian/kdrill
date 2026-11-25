import pytest

import lora as L
import targets as G
from kdlib import kdtest, refimpl as I, tasks as T


@pytest.fixture(scope="module")
def world():
    m, tok = I.ref_base()
    rows = T.read_jsonl("/kdlib/kdlib/data/qa_train.jsonl")
    ev = T.read_jsonl("/kdlib/kdlib/data/qa_eval.jsonl")[:40]
    return m, tok, I.qa_items(tok, rows), ev


def test_no_libraries():
    """hand-written: no peft, trl, transformers"""
    kdtest.assert_no_imports("targets", {"peft", "trl", "transformers", "accelerate"})


def test_select_targets():
    """groups map to layer names; unknown groups raise ValueError"""
    assert G.select_targets("qv") == ("query", "value") and G.select_targets("mlp") == ("fc1", "fc2")
    assert set(G.select_targets("attention")) == {"key", "query", "value", "proj"}
    assert set(G.select_targets("attention+mlp")) == {"key", "query", "value", "proj", "fc1", "fc2"}
    with pytest.raises(ValueError):
        G.select_targets("everything")


def test_prediction_equals_the_real_count(world):
    """predict_trainable matches the count after add_lora for every group and several ranks, and does not modify the model"""
    m = world[0]
    for group in G.GROUPS:
        for r in (1, 4, 8):
            targets = G.select_targets(group)
            mm = I.clone(m)
            pred = G.predict_trainable(mm, targets, r)
            assert not any(isinstance(x, L.LoRALinear) for x in mm.modules()) and all(p.requires_grad for p in mm.parameters())
            L.add_lora(mm, targets, r, 2 * r)
            assert pred == L.trainable_count(mm), "%s r=%d: predicted %d, real %d" % (group, r, pred, L.trainable_count(mm))


def test_compare_targets_structure(world):
    """one row per group in order with predicted equal to trainable, format and exact in [0, 1]"""
    m, tok, items, ev = world
    rows = G.compare_targets(m, tok, items, ev[:6], ["qv", "mlp"], steps=3)
    assert [r["group"] for r in rows] == ["qv", "mlp"]
    for r in rows:
        assert r["predicted"] == r["trainable"] > 0 and 0 <= r["format"] <= 1 and 0 <= r["exact"] <= 1
    assert rows[0]["trainable"] == 3 * 4 * 2 * 8 * (96 + 24)
    assert not any(isinstance(x, L.LoRALinear) for x in m.modules()), "the base model must stay untouched"


def test_mlp_adapters_matter_for_facts(world):
    """250 steps on the question-answer task: attention+MLP adapters reach at least 0.08 more exact match than attention only; both answer in format"""
    m, tok, items, ev = world
    rows = {r["group"]: r for r in G.compare_targets(m, tok, items, ev, ["attention", "attention+mlp"], steps=250)}
    a, b = rows["attention"], rows["attention+mlp"]
    assert a["format"] >= 0.9 and b["format"] >= 0.9, "format: %.2f / %.2f" % (a["format"], b["format"])
    assert b["exact"] >= a["exact"] + 0.08, "exact match: attention %.2f, attention+mlp %.2f" % (a["exact"], b["exact"])
