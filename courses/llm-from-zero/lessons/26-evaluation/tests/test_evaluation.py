import json
import math
import os

import numpy as np
import pytest
import torch
import torch.nn as nn
import torch.nn.functional as F

import evaluation as E
from gpt import GPT


class TableLM(nn.Module):
    """a model whose prediction depends only on the previous token: P(next | prev) = table[prev]"""
    def __init__(self, table, block_size=8):
        super().__init__()
        self.register_buffer("logt", torch.log(torch.as_tensor(table, dtype=torch.float32)))
        self.block_size, self.seen = block_size, []

    def forward(self, idx, targets=None):
        self.seen.append(tuple(idx.shape))
        return self.logt[idx], None


def table(V=6, seed=0):
    return torch.distributions.Dirichlet(torch.ones(V)).sample((V,)) if False else torch.softmax(torch.randn(V, V, generator=torch.Generator().manual_seed(seed)) * 1.5, dim=1)


def analytic(tab, ids):
    p = tab[ids[:-1], ids[1:]]
    return float(-torch.log(p).mean())


def test_perplexity_scores_every_token_exactly_once():
    """for a model that only looks at the previous token, any block_size and stride give the exact analytic loss over len-1 tokens"""
    tab = table()
    ids = torch.randint(0, 6, (103,), generator=torch.Generator().manual_seed(1))
    want = analytic(tab, ids)
    for block, stride in [(8, None), (8, 8), (8, 3), (16, 5), (100, 1), (200, None), (7, 7), (13, 4)]:
        m = TableLM(tab, block_size=block)
        r = E.perplexity_on_text(m, ids, block_size=block, stride=stride)
        assert r["tokens"] == 102, (block, stride, r["tokens"])
        assert r["loss"] == pytest.approx(want, abs=1e-4), (block, stride)
        assert r["perplexity"] == pytest.approx(math.exp(r["loss"]))


def test_defaults_and_independence_of_batch_size():
    """block_size defaults to the model's, stride to block_size, and batch_size never changes the answer"""
    tab = table(seed=2)
    ids = torch.randint(0, 6, (50,), generator=torch.Generator().manual_seed(3))
    m = TableLM(tab, block_size=9)
    a = E.perplexity_on_text(m, ids)
    b = E.perplexity_on_text(m, ids, batch_size=1)
    c = E.perplexity_on_text(m, ids, batch_size=64)
    assert a["tokens"] == 49 and a["loss"] == pytest.approx(b["loss"]) == pytest.approx(c["loss"], abs=1e-6)
    assert max(s[1] for s in m.seen) <= 9, "windows must not be longer than block_size"
    assert E.perplexity_on_text(m, ids[:2])["tokens"] == 1


def test_context_matters_for_a_real_gpt_and_mode_is_restored():
    """with a GPT, a small stride (more context) is not worse than non-overlapping windows on repetitive text; mode and grads untouched"""
    torch.manual_seed(0)
    m = GPT(10, 16, 2, 2, 32)
    x = torch.tensor(np.tile(np.arange(10), 40))
    opt = torch.optim.AdamW(m.parameters(), lr=5e-3)
    for _ in range(150):
        i = torch.randint(0, 300, (16,))
        xb = torch.stack([x[j:j + 16] for j in i]); yb = torch.stack([x[j + 1:j + 17] for j in i])
        opt.zero_grad(); m(xb, yb)[1].backward(); opt.step()
    m.train()
    full = E.perplexity_on_text(m, x, stride=16)
    sliding = E.perplexity_on_text(m, x, stride=2)
    assert m.training is True and all(p.grad is not None for p in m.parameters()) and full["tokens"] == sliding["tokens"] == 399
    assert sliding["loss"] <= full["loss"] + 1e-6
    assert full["loss"] < 0.5


def test_bits_per_char():
    """bits per char = loss * tokens / (chars * ln 2): a token model and a char model of the same text compare"""
    assert E.bits_per_char(math.log(2), 100, 100) == pytest.approx(1.0)
    assert E.bits_per_char(2.0, 50, 200) == pytest.approx(2.0 * 50 / (200 * math.log(2)))


def test_continuation_logprob_is_the_sum_of_conditional_log_probs():
    """the total log-probability of a continuation equals the sum of log p(next | previous) for a table model; errors on bad input"""
    tab = table(seed=4)
    m = TableLM(tab, block_size=8)
    prompt, cont = [1, 4, 2], [5, 0, 3]
    want = sum(math.log(tab[a, b]) for a, b in zip([2, 5, 0], cont))
    assert E.continuation_logprob(m, prompt, cont) == pytest.approx(want, abs=1e-5)
    assert E.continuation_logprob(m, prompt, [5]) == pytest.approx(math.log(tab[2, 5]), abs=1e-5)
    with pytest.raises(ValueError):
        E.continuation_logprob(m, [1] * 6, [2] * 3)
    with pytest.raises(ValueError):
        E.continuation_logprob(m, [], [1])
    with pytest.raises(ValueError):
        E.continuation_logprob(m, [1], [])


def test_run_probes():
    """a probe passes when the good continuation beats every bad one; accuracy is the share passed"""
    tab = torch.full((4, 4), 0.01)
    tab[0, 1] = 0.97; tab[1, 2] = 0.97; tab[2, 3] = 0.97; tab[3, 0] = 0.97
    tab = tab / tab.sum(1, keepdim=True)
    m = TableLM(tab, block_size=8)
    enc = lambda s: [int(c) for c in s]
    probes = [{"prompt": "0", "good": "12", "bad": ["20", "33"]},      # 0->1->2 likely: passes
              {"prompt": "0", "good": "30", "bad": ["12"]},            # unlikely beats likely: fails
              {"prompt": "3", "good": "0", "bad": ["1", "2"]}]
    r = E.run_probes(m, enc, probes)
    assert [d["passed"] for d in r["details"]] == [True, False, True] and r["accuracy"] == pytest.approx(2 / 3)
    assert r["details"][0]["good"] > max(r["details"][0]["bad"]) and len(r["details"][0]["bad"]) == 2
    assert E.run_probes(m, enc, [])["accuracy"] == 0.0


def test_contamination():
    """contamination is the share of test n-grams found in train (with examples in order); no n-grams gives 0"""
    train = "the quick brown fox jumps over the lazy dog every single morning"
    test = "The quick brown fox jumps over a sleepy cat. the lazy dog every single morning"
    rate, ex = E.contamination(train, test, n=4)
    grams = ["the quick brown fox", "quick brown fox jumps", "brown fox jumps over", "fox jumps over a", "jumps over a sleepy", "over a sleepy cat",
             "a sleepy cat the", "sleepy cat the lazy", "cat the lazy dog", "the lazy dog every", "lazy dog every single", "dog every single morning"]
    hits = [g for g in grams if g in {" ".join(train.split()[i:i + 4]) for i in range(len(train.split()) - 3)}]
    assert rate == pytest.approx(len(hits) / len(grams)) and ex == hits[:3]
    assert E.contamination(train, "too short", n=4) == (0.0, []) and E.contamination(train, train, n=3)[0] == 1.0
    assert E.contamination("", test, n=4)[0] == 0.0


def test_side_by_side_is_blinded_and_reversible(tmp_path):
    """the sheet shows both samples without names, in a seeded random order per prompt; the key file unblinds it"""
    prompts = ["p%d" % i for i in range(20)]
    a = ["A-text-%d" % i for i in range(20)]
    b = ["B-text-%d" % i for i in range(20)]
    path = str(tmp_path / "sheet.md")
    key = E.write_side_by_side(path, prompts, a, b, "base", "tuned", seed=3)
    text = open(path, encoding="utf-8").read()
    assert text.startswith("# Side by side") and "base" not in text and "tuned" not in text
    assert json.load(open(path + ".key.json")) == key and len(key) == 20
    assert {k["sample1"] for k in key} == {"base", "tuned"}, "both orders must occur over 20 prompts"
    for i, k in enumerate(key):
        sec = text.split("## Prompt %d\n" % (i + 1))[1].split("## Prompt %d\n" % (i + 2))[0]
        s1 = sec.split("Sample 1")[1].split("Sample 2")[0]; s2 = sec.split("Sample 2")[1]
        want1, want2 = (a[i], b[i]) if k["sample1"] == "base" else (b[i], a[i])
        assert want1 in s1 and want2 in s2 and "p%d" % i in sec.split("Sample 1")[0]
    again = E.write_side_by_side(str(tmp_path / "s2.md"), prompts, a, b, "base", "tuned", seed=3)
    other = E.write_side_by_side(str(tmp_path / "s3.md"), prompts, a, b, "base", "tuned", seed=4)
    assert again == key and other != key
