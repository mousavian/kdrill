import json
import math
import os

import pytest
import torch
import torch.nn as nn

import harness
from kdlib import kdtest, refimpl as I, tasks as T


@pytest.fixture(scope="module")
def base():
    return I.ref_base()


class Uniform(nn.Module):
    """predicts every token with equal probability"""
    def __init__(self, V=50, block=16):
        super().__init__()
        self.V, self.block_size = V, block
        self.w = nn.Parameter(torch.zeros(1))

    def forward(self, x, y=None):
        return torch.zeros(x.shape[0], x.shape[1], self.V) + self.w, None


class Script(nn.Module):
    """next token = table[last token]; records the longest input it saw"""
    def __init__(self, table, V, block=8):
        super().__init__()
        self.table, self.V, self.block_size, self.longest = table, V, block, 0
        self.w = nn.Parameter(torch.zeros(1))

    def forward(self, x, y=None):
        self.longest = max(self.longest, x.shape[1])
        logits = torch.zeros(x.shape[0], x.shape[1], self.V)
        for b in range(x.shape[0]):
            for t in range(x.shape[1]):
                logits[b, t, self.table.get(int(x[b, t]), 0)] = 10.0
        return logits, None


def test_no_fine_tuning_libraries():
    """the harness is plain PyTorch"""
    kdtest.assert_no_imports("harness", {"peft", "trl", "transformers", "accelerate", "lm_eval", "evaluate"})


def test_text_loss_matches_reference(base):
    """text_loss equals the mean NLL per token of the held-out text (checked on real text, window 64 and 20)"""
    m, tok = base
    ids = I.ids_of(tok, T.alice("val"))[:700]
    for w in (None, 20):
        got = harness.text_loss(m, ids, w)
        want = I.text_loss(m, ids, w or m.block_size)
        assert got == pytest.approx(want, abs=1e-4), "window %s: %.4f instead of %.4f" % (w, got, want)


def test_text_loss_weights_tokens_not_windows():
    """the short last window counts for its own number of tokens; a uniform model scores ln V"""
    m = Uniform(50, 16)
    for n in (17, 33, 40):
        assert harness.text_loss(m, torch.arange(n) % 50) == pytest.approx(math.log(50), abs=1e-5)
    m = Script({1: 2, 2: 3, 3: 4}, 6, block=4)         # predicts t+1 after 1,2,3 right and everything else wrong
    ids = torch.tensor([1, 2, 3, 4, 1, 2, 3, 5, 5])    # 8 targets, scored in windows of 4 and 4
    want = I.text_loss(m, ids, 4)
    assert harness.text_loss(m, ids, 4) == pytest.approx(want, abs=1e-5)
    ids = torch.tensor([1, 2, 3, 4, 1, 2, 3, 5, 5, 5])  # 9 targets: windows of 4, 4 and 1
    assert harness.text_loss(m, ids, 4) == pytest.approx(I.text_loss(m, ids, 4), abs=1e-5)


def test_text_loss_modes_and_errors(base):
    """no gradients are kept, the training/eval mode is restored, and fewer than two tokens is an error"""
    m, tok = base
    ids = I.ids_of(tok, T.alice("val"))[:100]
    m.train()
    harness.text_loss(m, ids)
    assert m.training
    assert all(p.grad is None for p in m.parameters())
    m.eval()
    harness.text_loss(m, ids)
    assert not m.training
    with pytest.raises(ValueError):
        harness.text_loss(m, ids[:1])


def test_complete_greedy_and_stop():
    """complete follows the arg-max token, stops at the end-of-text token (not part of the output) and reports it"""
    tok = I.R.BPE.train("a b c d e f g h", 10)
    eos = tok.special_ids[harness.EOS]
    a, b = tok.encode("x")[0], tok.encode(" yes")[0]
    prompt = "Q: ok\nA:"
    last = tok.encode(prompt)[-1]
    m = Script({last: b, b: eos}, tok.vocab_size, block=16)
    text, fin = harness.complete(m, tok, prompt)
    assert fin is True and text == tok.decode([b])
    m = Script({last: b, b: b}, tok.vocab_size, block=16)
    text, fin = harness.complete(m, tok, prompt, max_new_tokens=5)
    assert fin is False and text == tok.decode([b] * 5)


def test_complete_crops_the_context():
    """a prompt longer than the context window is cropped to the last block_size tokens"""
    tok = I.R.BPE.train("a b c d e f g h", 10)
    eos = tok.special_ids[harness.EOS]
    m = Script({}, tok.vocab_size, block=8)
    harness.complete(m, tok, "word " * 40, max_new_tokens=6)
    assert m.longest == 8, "the model saw %d tokens at once, the window is 8" % m.longest


def test_format_and_exact_match():
    """format_ok needs: finished, a leading space, some text, no newline; exact_match is ' ' + answer"""
    f = harness.format_ok
    assert f(" grey", True) and f(" the old room", True)
    assert not f(" grey", False) and not f("grey", True) and not f("  ", True) and not f("", True) and not f(" grey\nQ: x", True)
    assert harness.exact_match(" grey", "grey") and not harness.exact_match("grey", "grey") and not harness.exact_match(" grey ", "grey")
    assert not harness.exact_match(" gray", "grey")


def test_evaluate_qa_counts(monkeypatch):
    """evaluate_qa builds the prompt with PROMPT, completes each row and counts format and exact correctly"""
    rows = [{"question": "q%d" % i, "answer": "a%d" % i} for i in range(8)]
    seen = []
    script = {"q0": (" a0", True), "q1": (" a1", True), "q2": (" wrong", True), "q3": (" a3 and more", True),
              "q4": (" a4", False), "q5": ("a5", True), "q6": (" a6\nQ: x", True), "q7": (" a7", True)}

    def fake(model, tok, prompt, max_new_tokens=24):
        seen.append(prompt)
        return script[prompt[3:prompt.index("\n")]]

    monkeypatch.setattr(harness, "complete", fake)
    r = harness.evaluate_qa(None, None, rows)
    assert seen[0] == "Q: q0\nA:" and len(seen) == 8
    assert r["n"] == 8 and r["format"] == pytest.approx(5 / 8) and r["exact"] == pytest.approx(3 / 8)


def test_evaluate_on_the_base_model(base):
    """on the reference base model: style loss and original loss as measured independently, and it never answers in format"""
    m, tok = base
    style, orig = I.ids_of(tok, T.alice("val"))[:3000], I.ids_of(tok, T.holmes("val"))[:3000]
    rows = T.read_jsonl("/kdlib/kdlib/data/qa_eval.jsonl")[:6]
    r = harness.evaluate(m, tok, style, orig, rows)
    assert set(r) >= {"style_loss", "orig_loss", "format", "exact", "n_qa"} and r["n_qa"] == 6
    assert r["style_loss"] == pytest.approx(I.text_loss(m, style), abs=1e-4)
    assert r["orig_loss"] == pytest.approx(I.text_loss(m, orig), abs=1e-4)
    assert r["style_loss"] > r["orig_loss"] + 0.2, "the base model should be worse on the new style than on its own"
    assert r["format"] == 0.0 and r["exact"] == 0.0


def test_write_results(tmp_path):
    """write_results saves sorted, indented JSON with a trailing newline and creates the folder"""
    p = str(tmp_path / "deep" / "r.json")
    harness.write_results(p, {"b": 1.5, "a": 2})
    text = open(p).read()
    assert text.endswith("\n") and json.loads(text) == {"a": 2, "b": 1.5}
    assert text.index('"a"') < text.index('"b"') and "\n  " in text
    assert harness.read_results(p) == {"a": 2, "b": 1.5}
