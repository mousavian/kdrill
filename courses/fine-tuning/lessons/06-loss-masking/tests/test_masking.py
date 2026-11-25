import math

import pytest
import torch
import torch.nn.functional as F

import masking as M
from kdlib import kdtest, refimpl as I, tasks as T


@pytest.fixture(scope="module")
def world():
    m, tok = I.ref_base()
    rows = T.read_jsonl("/kdlib/kdlib/data/qa_train.jsonl")
    ev = T.read_jsonl("/kdlib/kdlib/data/qa_eval.jsonl")
    return m, tok, I.qa_items(tok, rows), ev


def test_no_libraries():
    """plain PyTorch: no peft, trl, transformers"""
    kdtest.assert_no_imports("masking", {"peft", "trl", "transformers", "accelerate"})


def test_make_batch_layout():
    """x and y are the shifted ids padded on the right; the mask marks exactly the completion targets"""
    items = [([5, 6, 7, 8, 9], 3), ([1, 2, 3], 2)]
    x, y, m = M.make_batch(items, pad_id=99)
    assert x.tolist() == [[5, 6, 7, 8], [1, 2, 99, 99]] and y.tolist() == [[6, 7, 8, 9], [2, 3, 99, 99]]
    assert m.tolist() == [[0, 0, 1, 1], [0, 1, 0, 0]], m.tolist()
    assert x.dtype == y.dtype == torch.long and m.dtype.is_floating_point


def test_masked_loss_value_and_errors():
    """a uniform model gives ln V on the selected positions; only the selected positions count; empty mask is an error"""
    V = 7
    logits = torch.zeros(2, 4, V)
    y = torch.randint(0, V, (2, 4))
    mask = torch.tensor([[0, 0, 1, 1], [0, 1, 0, 0]], dtype=torch.float)
    assert float(M.masked_loss(logits, y, mask)) == pytest.approx(math.log(V), abs=1e-6)
    logits = torch.randn(2, 4, V)
    nll = -F.log_softmax(logits, -1).gather(-1, y[..., None])[..., 0]
    want = (nll * mask).sum() / 3
    assert float(M.masked_loss(logits, y, mask)) == pytest.approx(float(want), abs=1e-6), "mean over the selected tokens, not over the batch"
    with pytest.raises(ValueError):
        M.masked_loss(logits, y, torch.zeros(2, 4))


def test_prompt_positions_get_zero_gradient(world):
    """backward through the real model: the gradient of the loss with respect to the logits is exactly zero at prompt and padding positions, non-zero on answers"""
    m, tok, items, _ = world
    mm = I.clone(m)
    batch = items[:6]
    x, y, mask = M.make_batch(batch, pad_id=0)
    logits, _ = mm(x)
    logits.retain_grad()
    M.masked_loss(logits, y, mask).backward()
    g = logits.grad.abs().sum(-1)
    assert float(g[mask == 0].abs().max()) == 0.0, "a prompt or padding position still has gradient"
    assert bool((g[mask == 1] > 0).all()), "an answer position got no gradient"
    assert (mask.sum(1) >= 2).all()


def test_batch_loss_equals_per_example_sums(world):
    """with padding, the batch loss equals the sum of every example's answer-token losses over the number of answer tokens"""
    m, tok, items, _ = world
    batch = [items[0], items[40], items[100], items[7]]
    x, y, mask = M.make_batch(batch, pad_id=0)
    got = float(M.masked_loss(m(x)[0], y, mask))
    tot, n = 0.0, 0
    for ids, pl in batch:
        t = torch.tensor(ids)
        lg = m(t[:-1][None])[0][0]
        nll = F.cross_entropy(lg, t[1:], reduction="none")
        tot += float(nll[pl - 1:].sum())
        n += len(ids) - pl
    assert got == pytest.approx(tot / n, abs=1e-4), "padding must not change the loss"


def test_train_sft_runs_and_is_reproducible(world):
    """same seed, same weights; frozen parameters stay put; one loss per step"""
    m, tok, items, _ = world
    a, b = I.clone(m), I.clone(m)
    for p in b.tok_emb.parameters():
        p.requires_grad = False
    emb = b.tok_emb.weight.detach().clone()
    la = M.train_sft(a, items, steps=3, lr=1e-3, batch_size=4, seed=5)
    lb = M.train_sft(I.clone(m), items, steps=3, lr=1e-3, batch_size=4, seed=5)
    assert len(la) == 3 and la == lb
    M.train_sft(b, items, steps=3, lr=1e-3, batch_size=4, seed=5)
    assert torch.equal(b.tok_emb.weight, emb), "a frozen parameter changed"


def test_model_learns_the_format_and_most_answers(world):
    """250 steps at lr 2e-3: at least 95% of held-out prompts are answered in the format, at least 45% exactly right"""
    m, tok, items, ev = world
    torch.manual_seed(0)
    mm = I.clone(m)
    losses = M.train_sft(mm, items, steps=250, lr=2e-3, seed=0)
    assert sum(losses[-20:]) < sum(losses[:20]) * 0.5
    r = I.qa_eval(mm, tok, ev, 40)
    assert r["format"] >= 0.95, "format accuracy %.2f" % r["format"]
    assert r["exact"] >= 0.45, "exact match %.2f" % r["exact"]
