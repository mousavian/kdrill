import json
import os
import random
import re

import pytest
import torch

import capstone as C
import lora as L
import masking
from kdlib import kdtest, refimpl as I, tasks as T

NAMES = ["Ada", "Ben", "Cora", "Dan", "Eve", "Finn"]
TEMPLATES = ["Who owns the {x}?", "The {x} belongs to whom?", "Whose is the {x}?"]
LIMITS = "It only knows the forty things of this toy task, answers nothing else, and the evaluation set is small so one question moves the score by two and a half points."


def owner_task(seed):
    """a task the learner has never seen: who owns which thing (40 things, 3 phrasings each); held-out phrasings"""
    rnd = random.Random(seed)
    ents = sorted(rnd.sample(T.WORDS[:T.WORDS.index("brave")], 40))
    facts = {x: rnd.choice(NAMES) for x in ents}
    tr, ev = [], []
    for x in ents:
        ph = [{"question": t.format(x=x), "answer": facts[x]} for t in TEMPLATES]
        rnd.shuffle(ph)
        k = rnd.choice((1, 1, 2))
        ev += ph[:k]
        tr += ph[k:]
    return tr, ev[:40]


def pinned(tmp, **kw):
    """the tests always run on the course's reference base model, whatever base/checkpoint.pt in your workspace is"""
    d = tmp / "base"
    d.mkdir(exist_ok=True)
    if not (d / "checkpoint.pt").exists():
        with open("/kdlib/kdlib/data/ref_base.pt", "rb") as f:
            (d / "checkpoint.pt").write_bytes(f.read())
        (d / "SOURCE.txt").write_text("the reference base model that ships with the course (test)\n")
        (tmp / "orig.txt").write_text(T.holmes("val"))
    return dict(kw, base_path=str(d / "checkpoint.pt"), orig_text=str(tmp / "orig.txt"))


@pytest.fixture(scope="module")
def run(tmp_path_factory):
    tr, ev = owner_task(7)
    seen = []
    real = masking.train_sft

    def spy(model, items, *a, **kw):
        seen.append(items)
        return real(model, items, *a, **kw)

    C.train_sft = spy
    planted = ev[:4]
    tmp = tmp_path_factory.mktemp("cap")
    out = str(tmp / "lora")
    res = C.run_capstone(tr + planted + [dict(tr[0])], ev, out, pinned(tmp, seeds=[0], steps=150), LIMITS)
    C.train_sft = real
    return tr, ev, planted, out, res, seen


def test_imports_your_earlier_work_and_no_libraries():
    """the capstone is built from your modules (sft_data, masking, lora, harness, trust, base) and from no fine-tuning library"""
    assert {"sft_data", "masking", "lora", "harness", "trust", "base"} <= kdtest.imported_modules("capstone")
    kdtest.assert_no_imports("capstone", {"peft", "trl", "transformers", "accelerate", "bitsandbytes", "datasets"})


def test_the_contract_of_the_results(run):
    """results.json and the returned dict have the documented fields and agree; the artifact exists; the counts are right"""
    tr, ev, planted, out, res, seen = run
    for k in ("method", "n_train", "n_eval", "n_removed", "n_too_long", "trainable", "config", "base", "tuned", "exact_per_seed", "exact_std"):
        assert k in res, k
    disk = json.load(open(os.path.join(out, "results.json")))
    assert disk == json.loads(json.dumps(res)) and open(os.path.join(out, "results.json")).read().endswith("\n")
    assert res["method"] == "lora" and res["n_eval"] == len(ev) and res["n_removed"] == len(planted) and res["n_too_long"] == 0
    assert res["n_train"] == len(tr), "the duplicate row must be cleaned away and the planted evaluation rows removed (%d vs %d)" % (res["n_train"], len(tr))
    assert res["trainable"] == 62208 and res["exact_std"] == 0.0 and len(res["exact_per_seed"]) == 1
    for m in ("base", "tuned"):
        assert set(res[m]) >= {"format", "exact", "orig_loss"} and 0 <= res[m]["exact"] <= 1 and res[m]["orig_loss"] > 0
    assert os.path.getsize(os.path.join(out, "adapter.pt")) > 1000 and os.path.exists(os.path.join(out, "MODEL_CARD.md"))


def test_the_evaluation_questions_never_reach_training(run):
    """the training items given to train_sft contain none of the evaluation questions, even though four were planted in the training file"""
    tr, ev, planted, out, res, seen = run
    m, tok = I.ref_base()
    assert len(seen) == 1
    train_ids = {tuple(ids) for ids, _ in seen[0]}
    for e in ev:
        ids, _ = I.encode_qa(tok, e["question"], e["answer"])
        assert tuple(ids) not in train_ids, "evaluation question reached training: %s" % e["question"]
    assert len(seen[0]) == len(tr)


def test_tuning_beats_the_base_and_the_numbers_are_real(run):
    """the base never answers in the format (exact 0), the tuned model answers in format on at least 90% and exactly on at least 70% of held-out questions; rerunning the evaluation from the saved adapter gives the reported numbers"""
    tr, ev, planted, out, res, seen = run
    assert res["base"]["format"] == 0.0 and res["base"]["exact"] == 0.0
    assert res["tuned"]["format"] >= 0.9, res["tuned"]
    assert res["tuned"]["exact"] >= 0.7, res["tuned"]
    m, tok = I.ref_base()
    L.add_lora(m, C.ATTENTION + C.MLP, 8, 16.0)
    L.load_adapter(m, os.path.join(out, "adapter.pt"))
    again = I.qa_eval(m, tok, ev)
    assert again["exact"] == pytest.approx(res["exact_per_seed"][0], abs=1e-9) and again["format"] == pytest.approx(res["tuned"]["format"], abs=1e-9), \
        "the saved adapter does not reproduce the reported numbers: %s vs %s" % (again, res["tuned"])
    assert any(float(p.abs().sum()) > 0 for n, p in L.lora_parameters(m) if n.endswith("lora_B")), "the saved adapter is empty"


def test_model_card_carries_the_numbers(run):
    """the model card has the six sections in order, every number of results.json as plain digits, your limitations text, and the source of the base model"""
    tr, ev, planted, out, res, seen = run
    card = open(os.path.join(out, "MODEL_CARD.md"), encoding="utf-8").read()
    heads = re.findall(r"^## (.+)$", card, flags=re.M)
    assert card.startswith("# Model card") and heads == ["Task", "Base model", "Data", "Method", "Results", "Limitations"], heads
    f3 = lambda x: "%.3f" % x
    for v in (res["base"]["exact"], res["tuned"]["exact"], res["base"]["format"], res["tuned"]["format"], res["base"]["orig_loss"], res["tuned"]["orig_loss"], res["exact_std"]):
        assert f3(v) in card, f3(v)
    for n in (res["n_train"], res["n_eval"], res["n_removed"], res["trainable"]):
        assert re.search(r"\b%d\b" % n, card), n
    assert LIMITS in card and "lora" in card.lower() and "reference base model" in card


def test_full_fine_tuning_and_several_seeds(tmp_path):
    """method 'full' trains every weight and saves tuned.pt (different from the base, reproducing the numbers); several seeds give per-seed values and their sample deviation; bad methods are refused"""
    tr, ev = owner_task(8)
    out = str(tmp_path / "full")
    res = C.run_capstone(tr, ev, out, pinned(tmp_path, method="full", steps=100, lr=1e-3, seeds=[0, 1]), LIMITS)
    assert res["method"] == "full" and res["trainable"] == 384864 and res["n_removed"] == 0 and len(res["exact_per_seed"]) == 2
    assert res["exact_std"] == pytest.approx(abs(res["exact_per_seed"][0] - res["exact_per_seed"][1]) / 2 ** 0.5, abs=1e-9)
    assert res["tuned"]["exact"] == pytest.approx(sum(res["exact_per_seed"]) / 2)
    m, tok = I.load_ckpt(os.path.join(out, "tuned.pt"))
    base, _ = I.ref_base()
    assert not torch.equal(m.lm_head.weight, base.lm_head.weight) and not torch.equal(m.blocks[0].ffn.fc1.weight, base.blocks[0].ffn.fc1.weight)
    assert I.qa_eval(m, tok, ev)["exact"] == pytest.approx(res["exact_per_seed"][0], abs=1e-9)
    assert res["tuned"]["exact"] >= 0.5, res["tuned"]
    with pytest.raises(ValueError):
        C.run_capstone(tr, ev, str(tmp_path / "x"), pinned(tmp_path, method="prompt-tuning"), LIMITS)
    with pytest.raises(ValueError):
        C.run_capstone([{"question": "", "answer": "x"}], ev, str(tmp_path / "y"), pinned(tmp_path, steps=2), LIMITS)
