import math
import os

import pytest
import torch
import torch.nn as nn

import train_gpt as tg
from gpt import GPT
from kdlib import kdtest
from kdlib.corpus import bundled_splits


def test_get_lr_schedule():
    """linear warm-up to max_lr, cosine decay to min_lr, then flat at min_lr"""
    lr = lambda s: tg.get_lr(s, 10, 110, 1.0, 0.1)
    assert lr(0) == pytest.approx(0.1) and lr(4) == pytest.approx(0.5) and lr(9) == pytest.approx(1.0)
    assert lr(10) == pytest.approx(1.0) and lr(60) == pytest.approx(0.55) and lr(110) == pytest.approx(0.1) and lr(5000) == pytest.approx(0.1)
    after = [lr(s) for s in range(10, 111)]
    assert all(a >= b - 1e-12 for a, b in zip(after, after[1:])), "decay must be monotone"
    assert [lr(s) for s in range(0, 10)] == sorted(lr(s) for s in range(0, 10))
    assert tg.get_lr(3, 5, 100, 3e-4, 3e-5) == pytest.approx(3e-4 * 4 / 5)


def test_clip_grad_norm_by_hand():
    """clip_grad_norm returns the pre-clip global norm, scales all gradients together, skips None gradients, and is not torch's helper"""
    kdtest.assert_not_used("train_gpt", {"clip_grad_norm_", "clip_grad_value_"})
    torch.manual_seed(0)
    ps = [nn.Parameter(torch.randn(3, 4)), nn.Parameter(torch.randn(5)), nn.Parameter(torch.randn(2))]
    for p in ps[:2]:
        p.grad = torch.randn_like(p) * 3
    ref = [p.grad.clone() for p in ps[:2]]
    total_ref = torch.sqrt(sum((g ** 2).sum() for g in ref)).item()
    got = tg.clip_grad_norm(ps, 1.0)
    assert isinstance(got, float) and got == pytest.approx(total_ref, rel=1e-6) and ps[2].grad is None
    new_norm = torch.sqrt(sum((p.grad ** 2).sum() for p in ps[:2])).item()
    assert new_norm == pytest.approx(1.0, rel=1e-4)
    ratio = ps[0].grad / ref[0]
    assert torch.allclose(ratio, torch.full_like(ratio, ratio.flatten()[0].item()), rtol=1e-4), "one common factor for all gradients"
    before = [p.grad.clone() for p in ps[:2]]
    assert tg.clip_grad_norm(ps, 100.0) == pytest.approx(new_norm, rel=1e-6)
    assert all(torch.equal(a, p.grad) for a, p in zip(before, ps[:2])), "no change when the norm is below the limit"


def test_checkpoint_round_trip(tmp_path):
    """save/load restore the model, the optimizer state, step and config, the global RNG and the data generator"""
    torch.manual_seed(0)
    m = GPT(20, 8, 1, 2, 16)
    opt = torch.optim.AdamW(m.parameters(), lr=1e-2)
    g = torch.Generator().manual_seed(5)
    x = torch.randint(0, 20, (4, 8))
    for _ in range(3):
        m(x, x)[1].backward(); opt.step(); opt.zero_grad()
    torch.rand(1, generator=g)
    p = str(tmp_path / "c.pt")
    tg.save_checkpoint(p, m, opt, 3, {"a": 1}, g)
    expected_rng = torch.rand(2); expected_data = torch.rand(2, generator=g)
    m2 = GPT(20, 8, 1, 2, 16)
    opt2 = torch.optim.AdamW(m2.parameters(), lr=1e-2)
    g2 = torch.Generator().manual_seed(0)
    ck = tg.load_checkpoint(p, m2, opt2, g2)
    assert ck["step"] == 3 and ck["config"] == {"a": 1}
    assert all(torch.equal(a, b) for a, b in zip(m.state_dict().values(), m2.state_dict().values()))
    assert len(opt2.state_dict()["state"]) == len(opt.state_dict()["state"]) > 0
    assert torch.equal(torch.rand(2), expected_rng) and torch.equal(torch.rand(2, generator=g2), expected_data)


def small_cfg(**kw):
    cfg = dict(block_size=16, batch_size=8, max_steps=20, warmup_steps=4, max_lr=5e-3, min_lr=5e-4, weight_decay=0.1,
               grad_clip=1.0, eval_every=5, eval_iters=2, save_every=10, seed=3)
    cfg.update(kw)
    return cfg


def toy_data():
    g = torch.Generator().manual_seed(0)
    return torch.randint(0, 20, (600,), generator=g), torch.randint(0, 20, (300,), generator=g)


def test_resume_is_bit_for_bit_identical(tmp_path):
    """stop at step 10, resume in a fresh model: the final weights, the losses and the schedule equal an uninterrupted run (with dropout)"""
    tr, va = toy_data()
    cfg = small_cfg()
    torch.manual_seed(11)
    a = GPT(20, 16, 2, 2, 32, dropout=0.1)
    ra = tg.train_run(a, tr, va, cfg, str(tmp_path / "a"))
    torch.manual_seed(11)
    b1 = GPT(20, 16, 2, 2, 32, dropout=0.1)
    r1 = tg.train_run(b1, tr, va, cfg, str(tmp_path / "b"), stop_after=10)
    assert len(r1["losses"]) == 10 and os.path.exists(tmp_path / "b" / "ckpt.pt")
    torch.manual_seed(999)       # a different init and RNG: everything must come from the checkpoint
    b2 = GPT(20, 16, 2, 2, 32, dropout=0.1)
    r2 = tg.train_run(b2, tr, va, cfg, str(tmp_path / "b"), resume=True)
    assert len(ra["losses"]) == 20 and len(r2["losses"]) == 10
    assert r1["losses"] + r2["losses"] == ra["losses"], "losses differ after resuming"
    assert r1["lrs"] + r2["lrs"] == ra["lrs"]
    for (k, va_), (_, vb) in zip(a.state_dict().items(), b2.state_dict().items()):
        assert torch.equal(va_, vb), "weights differ after resuming (%s)" % k


def test_schedule_clipping_and_bookkeeping(tmp_path):
    """the run applies get_lr every step, reports pre-clip gradient norms, evaluates every eval_every steps, and checkpoints the last step"""
    tr, va = toy_data()
    cfg = small_cfg(grad_clip=0.01, max_steps=12, save_every=100)
    torch.manual_seed(1)
    m = GPT(20, 16, 1, 2, 16)
    r = tg.train_run(m, tr, va, cfg, str(tmp_path))
    assert r["lrs"] == [tg.get_lr(s, 4, 12, 5e-3, 5e-4) for s in range(12)]
    assert len(r["grad_norms"]) == 12 and all(isinstance(x, float) and x > 0.01 for x in r["grad_norms"][:3]), "report the norm BEFORE clipping"
    assert [e["step"] for e in r["evals"]] == [0, 5, 10]
    ck = torch.load(str(tmp_path / "ckpt.pt"), weights_only=False)
    assert ck["step"] == 12 and {"model", "optimizer", "step", "config", "torch_rng", "data_rng"} <= set(ck)


def test_clipping_is_applied_before_the_optimizer_step(tmp_path, monkeypatch):
    """the gradients AdamW sees have a global norm of at most grad_clip, while the reported norms are the larger pre-clip ones"""
    tr, va = toy_data()
    seen = []
    orig = torch.optim.AdamW.step

    def spy_step(self, *a, **k):
        seen.append(math.sqrt(sum(float((p.grad ** 2).sum()) for g in self.param_groups for p in g["params"] if p.grad is not None)))
        return orig(self, *a, **k)
    monkeypatch.setattr(torch.optim.AdamW, "step", spy_step)
    torch.manual_seed(2)
    r = tg.train_run(GPT(20, 16, 1, 2, 16), tr, va, small_cfg(grad_clip=0.05, max_steps=6, save_every=100), str(tmp_path))
    assert len(seen) == 6 and max(seen) <= 0.0501, "the optimizer saw an unclipped gradient (norm %.3f)" % max(seen)
    assert max(r["grad_norms"]) > 0.1, "grad_norms must be the norms before clipping"


class Spy(nn.Module):
    def __init__(self, inner):
        super().__init__()
        self.inner, self.max_train_id = inner, -1

    def forward(self, idx, targets=None):
        if self.training:
            self.max_train_id = max(self.max_train_id, int(idx.max()))
        return self.inner(idx, targets)


def test_validation_tokens_never_train(tmp_path):
    """tokens that only exist in the validation data are never fed to the model in training mode"""
    tr = torch.randint(0, 10, (500,)); va = torch.randint(10, 20, (300,))
    torch.manual_seed(0)
    spy = Spy(GPT(20, 16, 1, 2, 16))
    tg.train_run(spy, tr, va, small_cfg(max_steps=8, save_every=100), str(tmp_path))
    assert 0 <= spy.max_train_id < 10


def test_it_actually_learns_text(tmp_path):
    """a tiny GPT on the real text: validation loss at step 150 is far below the start"""
    tr, va, _ = bundled_splits()
    chars = sorted(set(tr)); stoi = {c: i for i, c in enumerate(chars)}
    enc = lambda s: torch.tensor([stoi.get(c, 0) for c in s], dtype=torch.long)
    torch.manual_seed(0)
    m = GPT(len(chars), 32, 2, 2, 48)
    cfg = small_cfg(block_size=32, batch_size=16, max_steps=150, warmup_steps=10, max_lr=4e-3, min_lr=4e-4, eval_every=75, eval_iters=5, save_every=1000)
    r = tg.train_run(m, enc(tr[:200000]), enc(va[:50000]), cfg, str(tmp_path))
    first, last = r["evals"][0]["val_loss"], r["evals"][-1]["val_loss"]
    assert first > math.log(len(chars)) - 0.3 and last < 3.0 and last < first - 1.2, (first, last)
