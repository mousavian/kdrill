import json

import pytest
import torch
import torch.nn.functional as F

import prefs as P
from kdlib import kdtest, refimpl as I, tasks as T


@pytest.fixture(scope="module")
def world():
    m, tok = I.ref_base()
    return m, tok


def test_no_libraries():
    """plain PyTorch: no trl, peft, transformers"""
    kdtest.assert_no_imports("prefs", {"trl", "peft", "transformers", "accelerate", "datasets"})


def test_validity_rules():
    """each rule on its own: empty fields, identical answers, wrong direction, answers about different things, missing keys"""
    ok = {"prompt": "What colour is the lamp?", "chosen": "grey", "rejected": "I should say grey, naturally"}
    assert P.is_valid_pair(ok) and P.is_valid_pair({**ok, "prompt": "  q  ", "chosen": " grey ", "rejected": " I should say grey "})
    assert not P.is_valid_pair({**ok, "rejected": "  "}) and not P.is_valid_pair({**ok, "chosen": ""}) and not P.is_valid_pair({**ok, "prompt": " "})
    assert not P.is_valid_pair({**ok, "rejected": "grey"})                          # identical
    assert not P.is_valid_pair({**ok, "chosen": ok["rejected"], "rejected": ok["chosen"]})        # swapped
    assert not P.is_valid_pair({**ok, "rejected": "I should say blue, naturally"})   # does not contain the chosen answer
    assert not P.is_valid_pair({**ok, "chosen": "Elementary, grey"})                # the chosen one is chatty
    assert not P.is_valid_pair({"prompt": "q", "chosen": "a"}) and not P.is_valid_pair({**ok, "chosen": None})
    assert P.is_chatty("Why, grey, of course") and not P.is_chatty("grey")


def test_clean_pairs_on_a_fresh_file():
    """a newly generated messy preference file (seed 99): exactly the valid unique pairs survive, none with an evaluation prompt"""
    rows, truth = T.make_raw_pairs(seed=99)
    _, ev = T.train_eval_qa()
    ev_prompts = [e["question"] for e in ev]
    out = P.clean_pairs(rows, ev_prompts)
    prompts = [p["prompt"] for p in out]
    assert len(prompts) == len(set(prompts))
    assert set(prompts) == truth, "kept %d, expected %d; extra %s; missing %s" % (len(prompts), len(truth), sorted(set(prompts) - truth)[:2], sorted(truth - set(prompts))[:2])
    assert not set(prompts) & set(ev_prompts)
    assert all(P.is_valid_pair(p) for p in out)
    leaked = P.clean_pairs(rows)
    assert len(leaked) == len(truth) + 8, "without the exclusion list the 8 evaluation prompts stay"


def test_clean_pairs_details():
    """whitespace is stripped, the first duplicate wins, the input rows are not modified"""
    a = {"prompt": " q1 ", "chosen": " x ", "rejected": " Why, x, of course "}
    b = {"prompt": "q1", "chosen": "y", "rejected": "Why, y"}
    c = {"prompt": "q2", "chosen": "z", "rejected": "You see z"}
    snap = json.loads(json.dumps([a, b, c]))
    out = P.clean_pairs([a, b, c], exclude_prompts=[" q2"])
    assert out == [{"prompt": "q1", "chosen": "x", "rejected": "Why, x, of course"}]
    assert [a, b, c] == snap


def test_encode_pair(world):
    """prompt ids, then chosen and rejected completions ending in the end-of-text id, equal to encoding the whole string"""
    m, tok = world
    eos = tok.special_ids[P.EOS]
    p = {"prompt": "What colour is the lamp?", "chosen": "grey", "rejected": "I should say grey, naturally"}
    pr, ch, rj = P.encode_pair(tok, p)
    assert pr + ch == tok.encode("Q: What colour is the lamp?\nA: grey" + P.EOS) and pr + rj == tok.encode("Q: What colour is the lamp?\nA: I should say grey, naturally" + P.EOS)
    assert ch[-1] == rj[-1] == eos and all(isinstance(i, int) for i in pr + ch + rj)


def test_completion_logprobs_values(world):
    """equals the hand-computed sum of log-probabilities of the completion tokens for items of different lengths"""
    m, tok = world
    pairs = T.make_pairs(T.all_questions()[:4], 1)
    items = []
    for p in pairs:
        pr, ch, rj = P.encode_pair(tok, p)
        items += [(pr, ch), (pr, rj)]
    got = P.completion_logprobs(m, items)
    assert got.shape == (8,)
    for (pr, c), g in zip(items, got):
        seq = torch.tensor(pr + c)
        with torch.no_grad():
            lp = F.log_softmax(m(seq[:-1][None])[0][0], -1)
        want = sum(float(lp[len(pr) - 1 + i, c[i]]) for i in range(len(c)))
        assert float(g) == pytest.approx(want, abs=1e-3), (float(g), want)
    assert bool((got < 0).all())


def test_completion_logprobs_ignore_padding_and_company(world):
    """the value of an item does not change with the pad id or with what else is in the batch; the prompt itself is not scored"""
    m, tok = world
    pairs = T.make_pairs(T.all_questions()[10:13], 2)
    pr, ch, rj = P.encode_pair(tok, pairs[0])
    alone = P.completion_logprobs(m, [(pr, ch)])[0]
    long = [(P.encode_pair(tok, pairs[1])[0], P.encode_pair(tok, pairs[1])[2])]
    mixed = P.completion_logprobs(m, [(pr, ch)] + long, pad_id=7)[0]
    assert float(alone) == pytest.approx(float(mixed), abs=1e-4)
    other = P.completion_logprobs(m, [(pr[:-2] + [5, 6], ch)])[0]
    assert float(other) != pytest.approx(float(alone), abs=1e-3), "the prompt must condition the completion"


def test_completion_logprobs_are_differentiable(world):
    """backward reaches the model parameters; raising the log-probability of a completion by gradient steps works"""
    m, tok = world
    mm = I.clone(m)
    pr, ch, _ = P.encode_pair(tok, T.make_pairs(T.all_questions()[:1], 1)[0])
    before = float(P.completion_logprobs(mm, [(pr, ch)])[0])
    opt = torch.optim.AdamW(mm.parameters(), lr=2e-3)
    for _ in range(5):
        loss = -P.completion_logprobs(mm, [(pr, ch)]).sum()
        opt.zero_grad(); loss.backward(); opt.step()
    assert float(P.completion_logprobs(mm, [(pr, ch)])[0]) > before + 0.5


def test_length_gap(world):
    """the rejected answers are longer in the task's data: the report says by how much"""
    m, tok = world
    pairs = T.make_pairs(T.all_questions()[:50], 3)
    g = P.length_gap(pairs, tok)
    enc = [P.encode_pair(tok, p) for p in pairs]
    assert g["chosen_mean"] == pytest.approx(sum(len(c) for _, c, _ in enc) / 50) and g["rejected_mean"] == pytest.approx(sum(len(r) for _, _, r in enc) / 50)
    assert g["rejected_longer"] == 1.0 and g["rejected_mean"] > 2 * g["chosen_mean"]
