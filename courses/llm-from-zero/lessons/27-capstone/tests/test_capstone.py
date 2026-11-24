import math
import os
import random

import pytest
import torch

import capstone
from kdlib import kdtest

SUBJ = ["the detective", "a tall stranger", "the old doctor", "my friend", "the landlady", "a young clerk", "the inspector", "our visitor"]
VERB = ["found", "followed", "watched", "questioned", "remembered", "described", "discovered", "visited"]
OBJ = ["a red key", "the silver watch", "an old letter", "the broken lamp", "a locked box", "the muddy boots", "a torn map", "the wet umbrella"]
PLACE = ["in the cellar", "near the station", "behind the church", "on the staircase", "at the harbour", "by the river", "in the garden", "under the bridge"]


def make_raw(tmp_path, books=5, paras=70, seed=0):
    rnd = random.Random(seed)
    raw = tmp_path / "raw"
    raw.mkdir()
    for b in range(books):
        ps = []
        for _ in range(paras):
            sents = ["%s %s %s %s." % (rnd.choice(SUBJ).capitalize(), rnd.choice(VERB), rnd.choice(OBJ), rnd.choice(PLACE)) for _ in range(3)]
            ps.append(" ".join(sents))
        body = "\n\n".join(ps)
        (raw / ("book%d.txt" % b)).write_text("Header of book %d\n\n*** START OF THE PROJECT GUTENBERG EBOOK B%d ***\n\n%s\n\n*** END OF THE PROJECT GUTENBERG EBOOK B%d ***\nLicence\n" % (b, b, body, b), encoding="utf-8")
    return str(raw)


@pytest.fixture(scope="module")
def run(tmp_path_factory):
    tmp = tmp_path_factory.mktemp("cap")
    raw = make_raw(tmp)
    out = str(tmp / "out")
    res = capstone.run_pipeline(raw, out, {"max_steps": 120})
    return raw, out, res


def test_imports_your_earlier_work():
    """the capstone is built from your own modules: prepare, bpe, gpt, train_gpt, generate, evaluation"""
    assert {"prepare", "bpe", "gpt", "train_gpt", "generate", "evaluation"} <= kdtest.imported_modules("capstone")
    kdtest.assert_no_imports("capstone", {"transformers", "tiktoken", "tokenizers", "sentencepiece"})


def test_pipeline_outputs(run):
    """the run returns the documented fields and writes the dataset, the checkpoint and the model card"""
    raw, out, res = run
    assert {"checkpoint", "model_card", "val_loss", "test_loss", "test_perplexity", "bits_per_char", "n_params", "vocab_size", "samples"} <= set(res)
    for f in ("data/train.txt", "data/val.txt", "data/test.txt", "data/DATA_CARD.md", "checkpoint.pt", "MODEL_CARD.md"):
        assert os.path.getsize(os.path.join(out, f)) > 0, f
    assert res["checkpoint"] == os.path.join(out, "checkpoint.pt") and res["model_card"] == os.path.join(out, "MODEL_CARD.md")
    assert len(res["samples"]) == 3 and all(isinstance(s, str) and len(s) > 20 for s in res["samples"])
    assert res["test_perplexity"] == pytest.approx(math.exp(res["test_loss"]), rel=1e-6)
    assert res["vocab_size"] == 256 + 100 + 1 or res["vocab_size"] < 357


def test_it_learned_something(run):
    """validation and test loss are far below the loss of a model that knows nothing (ln V)"""
    _, _, res = run
    lnv = math.log(res["vocab_size"])
    assert res["val_loss"] < lnv - 1.0 and res["test_loss"] < lnv - 1.0, (res["val_loss"], res["test_loss"], lnv)
    assert 0 < res["bits_per_char"] < 8 * 0.8


def test_checkpoint_contract(run):
    """the checkpoint has the keys the fine-tuning course relies on, with consistent contents"""
    _, out, res = run
    ck = torch.load(res["checkpoint"], weights_only=False)
    assert {"model_state", "gpt_config", "tokenizer", "metrics", "train_config", "data_card", "course"} <= set(ck)
    assert ck["course"] == "llm-from-zero"
    assert set(ck["gpt_config"]) == {"vocab_size", "block_size", "n_layer", "n_head", "n_embd", "dropout"}
    assert ck["gpt_config"]["vocab_size"] == res["vocab_size"] and ck["gpt_config"]["block_size"] == 32
    assert ck["tokenizer"]["type"] == "bpe" and len(ck["tokenizer"]["merges"]) + 256 + len(ck["tokenizer"]["special_tokens"]) == res["vocab_size"]
    assert set(ck["metrics"]) == {"val_loss", "test_loss", "test_perplexity", "bits_per_char"}
    assert ck["metrics"]["test_loss"] == pytest.approx(res["test_loss"]) and ck["train_config"]["max_steps"] == 120
    assert ck["data_card"] == open(os.path.join(out, "data", "DATA_CARD.md"), encoding="utf-8").read()
    assert ck["model_state"]["tok_emb.weight"].shape == (res["vocab_size"], 48)


def test_load_for_finetuning_reproduces_the_reported_test_loss(run):
    """loading the checkpoint gives back a working model and tokenizer: their test loss equals the one stored in the checkpoint"""
    from evaluation import perplexity_on_text
    _, out, res = run
    model, tok = capstone.load_for_finetuning(res["checkpoint"])
    assert model.training is False
    test = open(os.path.join(out, "data", "test.txt"), encoding="utf-8").read()
    ids = torch.tensor(tok.encode(test), dtype=torch.long)
    r = perplexity_on_text(model, ids, stride=model.block_size // 2)
    assert r["loss"] == pytest.approx(res["test_loss"], abs=1e-4)
    text = "the detective found a red key"
    assert tok.decode(tok.encode(text)) == text


def test_model_card(run):
    """the model card has the sections in order, the numbers of this run, the samples, and real limitations"""
    _, out, res = run
    card = open(res["model_card"], encoding="utf-8").read()
    heads = ["# Model card", "## Model", "## Training data", "## Training", "## Evaluation", "## Samples", "## Intended use and limitations"]
    pos = [card.find(h + "\n") if i == 0 else card.find("\n" + h + "\n") for i, h in enumerate(heads)]
    assert all(p >= 0 for p in pos), [h for h, p in zip(heads, pos) if p < 0]
    assert pos == sorted(pos)
    for n in (res["n_params"], res["vocab_size"], 120):
        assert str(n) in card
    assert "%.2f" % res["test_perplexity"] in card
    for s in res["samples"]:
        assert s.strip().splitlines()[0] in card
    lim = card.split("## Intended use and limitations")[1]
    assert len(lim.strip()) >= 150 and "TODO" not in lim
    data_card = open(os.path.join(out, "data", "DATA_CARD.md"), encoding="utf-8").read()
    assert "book0.txt" in card and "sha256" in card.lower(), "the model card quotes the data card's sources"


def test_test_split_is_never_used_for_training(tmp_path, monkeypatch):
    """train_run receives exactly the encoded train and validation splits: the test split stays untouched until evaluation"""
    import train_gpt
    from bpe import BPE
    seen = {}
    real = train_gpt.train_run

    def spy(model, train_data, val_data, cfg, out_dir, **kw):
        seen["train"], seen["val"] = train_data.clone(), val_data.clone()
        return real(model, train_data, val_data, cfg, out_dir, **kw)
    monkeypatch.setattr(capstone, "train_run", spy)
    raw = make_raw(tmp_path, books=4, paras=40, seed=3)
    out = str(tmp_path / "o")
    capstone.run_pipeline(raw, out, {"max_steps": 6, "eval_every": 3, "merges": 30})
    ck = torch.load(os.path.join(out, "checkpoint.pt"), weights_only=False)
    tok = BPE.from_dict(ck["tokenizer"])
    rd = lambda n: open(os.path.join(out, "data", n + ".txt"), encoding="utf-8").read()
    assert torch.equal(seen["train"], torch.tensor(tok.encode(rd("train")))), "train_run must get the encoded training split"
    assert torch.equal(seen["val"], torch.tensor(tok.encode(rd("val")))), "train_run must get the encoded validation split"
    assert tok.merges == BPE.train(rd("train"), 30).merges, "the tokenizer must be trained on the training split only"


def test_same_config_same_result(tmp_path):
    """two runs with the same corpus and config give the same metrics and samples"""
    raw = make_raw(tmp_path, books=4, paras=40, seed=5)
    a = capstone.run_pipeline(raw, str(tmp_path / "a"), {"max_steps": 12, "eval_every": 6, "merges": 30})
    b = capstone.run_pipeline(raw, str(tmp_path / "b"), {"max_steps": 12, "eval_every": 6, "merges": 30})
    assert a["test_loss"] == b["test_loss"] and a["samples"] == b["samples"] and a["val_loss"] == b["val_loss"]
