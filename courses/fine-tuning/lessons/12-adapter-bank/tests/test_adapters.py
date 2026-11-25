import pytest
import torch

import adapters as A
import finetune
import masking
import lora as L
from kdlib import kdtest, refimpl as I, tasks as T


@pytest.fixture(scope="module")
def world():
    m, tok = I.ref_base()
    rows = T.read_jsonl("/kdlib/kdlib/data/qa_train.jsonl")
    return (m, tok, I.ids_of(tok, T.alice("train")), I.ids_of(tok, T.alice("val"))[:3000], I.qa_items(tok, rows),
            T.read_jsonl("/kdlib/kdlib/data/qa_eval.jsonl")[:30])


def test_no_libraries():
    """hand-written: no peft, trl, transformers"""
    kdtest.assert_no_imports("adapters", {"peft", "trl", "transformers", "accelerate"})


def test_one_base_copy_and_switching_is_exact(world):
    """the bank wraps the model you give it (the base Parameters are the same objects); with no adapter active the logits are the plain base's"""
    m = world[0]
    mm = I.clone(m)
    ref = {n: p for n, p in mm.named_parameters()}
    bank = A.AdapterBank(mm)
    assert bank.names() == [] and bank.active is None
    for n, p in mm.named_parameters():
        if "lora" not in n and ".base." not in n:
            assert p is ref[n], n
    x = torch.randint(0, 400, (2, 30))
    with torch.no_grad():
        assert torch.equal(mm(x)[0], m(x)[0])
        bank.add("a"); bank.add("b")
        bank.activate("a")
        assert torch.equal(mm(x)[0], m(x)[0]), "a fresh adapter (B = 0) must not change the output"
    assert bank.names() == ["a", "b"] and bank.active == "a"
    with pytest.raises(ValueError):
        bank.add("a")
    with pytest.raises(ValueError):
        bank.activate("zzz")
    with pytest.raises(ValueError):
        bank.remove("a")                    # the active one
    bank.remove("b")
    assert bank.names() == ["a"]


def test_fresh_adapters_differ_in_a_and_start_with_zero_b(world):
    """each added adapter has its own random A (different seeds) and zero B, with the shapes of lora_parameters"""
    mm = I.clone(world[0])
    bank = A.AdapterBank(mm, targets=("query", "value"), r=4, alpha=8)
    bank.add("a"); bank.add("b")
    sa, sb = bank.state("a"), bank.state("b")
    names = [n for n, _ in L.lora_parameters(mm)]
    assert set(sa) == set(sb) == set(names)
    for n in names:
        if n.endswith("lora_B"):
            assert float(sa[n].abs().sum()) == 0.0
        else:
            assert not torch.equal(sa[n], sb[n])
    assert bank.state("a")["blocks.0.attn.heads.0.query.lora_A"] is not sa["blocks.0.attn.heads.0.query.lora_A"], "state() must return copies"


def test_training_in_place_is_kept_and_adapters_do_not_interfere(world):
    """train 'style' with your finetune and 'qa' with train_sft: each keeps its own weights; switching back and forth gives identical logits; None gives the base"""
    m, tok, tr, va, items, ev = world
    mm = I.clone(m)
    bank = A.AdapterBank(mm)
    bank.add("style"); bank.activate("style")
    finetune.finetune(mm, tr, steps=20, lr=3e-3, warmup=5)
    style_state = bank.state("style")
    assert any(float(t.abs().sum()) > 0 for n, t in style_state.items() if n.endswith("lora_B"))
    bank.add("qa"); bank.activate("qa")
    assert float(sum(t.abs().sum() for n, t in bank.state("qa").items() if n.endswith("lora_B"))) == 0.0, "a new adapter must start fresh, not from the style adapter"
    masking.train_sft(mm, items, steps=20, lr=3e-3)
    x = torch.randint(0, 400, (2, 30))
    out = {}
    with torch.no_grad():
        for name in ("style", "qa", None, "style", "qa"):
            bank.activate(name)
            out.setdefault(name, []).append(mm(x)[0].clone())
    assert torch.equal(out["style"][0], out["style"][1]) and torch.equal(out["qa"][0], out["qa"][1])
    assert torch.equal(out[None][0], m(x)[0]) and not torch.equal(out["style"][0], out["qa"][0])
    after = bank.state("style")
    assert all(torch.equal(after[n], style_state[n]) for n in style_state), "training 'qa' changed the 'style' adapter"


def test_memory_report(world):
    """one base plus small adapters instead of one full model per task"""
    mm = I.clone(world[0])
    bank = A.AdapterBank(mm, r=8)
    bank.add("a"); bank.add("b"); bank.add("c")
    rep = bank.memory_report()
    assert rep["base_bytes"] == 4 * 384864
    per = rep["adapter_bytes"]["a"]
    assert per == 4 * 62208 and set(rep["adapter_bytes"]) == {"a", "b", "c"}
    assert rep["separate_models_bytes"] == 3 * rep["base_bytes"] and 3 * per < 0.5 * rep["separate_models_bytes"]


def test_two_tasks_two_adapters(world):
    """style adapter: held-out style loss at least 0.2 below the base, no answers in format; qa adapter: at least 90% format, better exact match than the style adapter"""
    m, tok, tr, va, items, ev = world
    mm = I.clone(m)
    bank = A.AdapterBank(mm)
    bank.add("style"); bank.activate("style")
    finetune.finetune(mm, tr, steps=100, lr=3e-3, warmup=10)
    bank.add("qa"); bank.activate("qa")
    masking.train_sft(mm, items, steps=200, lr=3e-3)
    res = {}
    for name in (None, "style", "qa"):
        bank.activate(name)
        res[name] = (I.text_loss(mm, va), I.qa_eval(mm, tok, ev))
    assert res["style"][0] < res[None][0] - 0.2, "style adapter: %.3f vs base %.3f" % (res["style"][0], res[None][0])
    assert res["style"][1]["format"] <= 0.1 and res[None][1]["format"] <= 0.1
    assert res["qa"][1]["format"] >= 0.9 and res["qa"][1]["exact"] > res["style"][1]["exact"] + 0.1
    assert res["qa"][0] > res["style"][0], "the qa adapter should not be better at the Alice style than the style adapter"
