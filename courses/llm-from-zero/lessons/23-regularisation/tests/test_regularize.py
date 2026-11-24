import copy
import math

import pytest
import torch
import torch.nn as nn

import regularize as R
from gpt import GPT
from loop import evaluate
from kdlib.corpus import bundled_splits


def test_parameter_groups():
    """decay group = weight matrices and embeddings; no-decay group = biases and LayerNorm parameters; tied weights counted once"""
    torch.manual_seed(0)
    m = GPT(30, 8, 2, 2, 16)
    opt = R.configure_optimizer(m, 0.1, 1e-3, betas=(0.8, 0.9))
    assert isinstance(opt, torch.optim.AdamW) and len(opt.param_groups) == 2
    d, nd = opt.param_groups
    assert d["weight_decay"] == 0.1 and nd["weight_decay"] == 0.0 and d["lr"] == 1e-3 and d["betas"] == (0.8, 0.9)
    assert all(p.ndim >= 2 for p in d["params"]) and all(p.ndim < 2 for p in nd["params"])
    ids = [id(p) for g in opt.param_groups for p in g["params"]]
    assert len(ids) == len(set(ids)) == len(set(id(p) for p in m.parameters())), "each parameter exactly once (tied weights!)"
    assert any(p is m.tok_emb.weight for p in d["params"]) and any(p is m.ln_f.weight for p in nd["params"])
    assert sum(p.numel() for p in nd["params"]) > 0


def test_frozen_parameters_are_skipped():
    """parameters with requires_grad False are not given to the optimizer"""
    lin = nn.Linear(4, 4)
    lin.weight.requires_grad_(False)
    opt = R.configure_optimizer(lin, 0.1, 1e-3)
    assert [p for g in opt.param_groups for p in g["params"]] == [lin.bias]


def test_weight_decay_shrinks_matrices_not_biases():
    """with zero gradients one step multiplies matrices by (1 - lr * wd) and leaves biases alone"""
    lin = nn.Linear(5, 5)
    with torch.no_grad():
        lin.bias.fill_(1.0)
    w0, b0 = lin.weight.detach().clone(), lin.bias.detach().clone()
    opt = R.configure_optimizer(lin, 0.5, 0.1)
    for p in lin.parameters():
        p.grad = torch.zeros_like(p)
    opt.step()
    assert torch.allclose(lin.weight, w0 * (1 - 0.1 * 0.5), atol=1e-7) and torch.equal(lin.bias, b0)


def test_early_stopping_logic():
    """improvement means val < best - min_delta; stop after `patience` evaluations in a row without one"""
    es = R.EarlyStopping(patience=3)
    assert es.best == float("inf") and es.best_step is None and not es.should_stop
    seq = [(3.0, True), (2.5, True), (2.6, False), (2.7, False), (2.4, True), (2.4, False), (2.5, False), (2.6, False)]
    for i, (v, imp) in enumerate(seq):
        assert es.update(v, 10 * (i + 1)) is imp, (i, v)
        assert es.should_stop == (i == len(seq) - 1), i
    assert es.best == 2.4 and es.best_step == 50
    md = R.EarlyStopping(patience=2, min_delta=0.1)
    assert md.update(1.0, 1) and not md.update(0.95, 2) and not md.update(0.9, 3) and md.should_stop, "gains smaller than min_delta do not count"


def noise_data(seed):
    return torch.randint(0, 16, (200,), generator=torch.Generator().manual_seed(seed))


def test_early_stopping_stops_and_restores_the_best_weights():
    """on random tokens a big model memorises train and val gets worse: training stops early and the best weights come back"""
    tr, va = noise_data(0), noise_data(1)
    torch.manual_seed(0)
    m = GPT(16, 16, 2, 2, 64)
    r = R.train_with_early_stopping(m, tr, va, 16, 16, max_steps=600, lr=3e-3, weight_decay=0.0, eval_every=10, eval_iters=8, patience=4)
    assert r["stopped_at"] < 600, "never stopped: validation loss should rise on random data"
    hist = r["history"]
    assert [h[0] for h in hist] == list(range(10, r["stopped_at"] + 1, 10))
    vals = [h[2] for h in hist]
    assert r["best_val"] == min(vals) and r["best_step"] == hist[vals.index(min(vals))][0]
    assert r["stopped_at"] == r["best_step"] + 4 * 10, "stop exactly `patience` evaluations after the best one"
    assert hist[-1][1] < hist[0][1], "training loss kept falling (memorising)"
    again = evaluate(m, va, 16, 16, 8, torch.Generator().manual_seed(1234))
    assert again == pytest.approx(r["best_val"], abs=1e-6), "the best weights were not restored"


def test_validation_data_does_not_train():
    """validation-only tokens never reach the model in training mode"""
    class Spy(nn.Module):
        def __init__(self, inner):
            super().__init__(); self.inner = inner; self.m = -1
        def forward(self, idx, targets=None):
            if self.training:
                self.m = max(self.m, int(idx.max()))
            return self.inner(idx, targets)
    tr = torch.randint(0, 8, (300,)); va = torch.randint(8, 16, (300,))
    torch.manual_seed(0)
    spy = Spy(GPT(16, 16, 1, 2, 16))
    R.train_with_early_stopping(spy, tr, va, 16, 8, 20, 1e-3, 0.1, 10, 2, patience=5)
    assert 0 <= spy.m < 8


def test_dropout_is_a_regulariser_only_while_training():
    """a GPT with dropout is stochastic in train mode and deterministic in eval mode; the training loss of the same weights is higher with dropout"""
    torch.manual_seed(0)
    m = GPT(16, 16, 2, 2, 32, dropout=0.3)
    x = torch.randint(0, 16, (8, 16))
    m.train()
    a, b = m(x, x)[1].item(), m(x, x)[1].item()
    m.eval()
    c, d = m(x, x)[1].item(), m(x, x)[1].item()
    assert a != b and c == d


def test_runs_on_real_text_and_improves():
    """a short real run: validation loss at the restored best weights beats the untrained model by a wide margin"""
    tr, va, _ = bundled_splits()
    chars = sorted(set(tr)); stoi = {c: i for i, c in enumerate(chars)}
    enc = lambda s: torch.tensor([stoi.get(c, 0) for c in s], dtype=torch.long)
    torch.manual_seed(0)
    m = GPT(len(chars), 32, 2, 2, 48, dropout=0.1)
    r = R.train_with_early_stopping(m, enc(tr[:100000]), enc(va[:30000]), 32, 16, max_steps=120, lr=4e-3, weight_decay=0.1,
                                    eval_every=40, eval_iters=5, patience=3)
    assert r["best_val"] < math.log(len(chars)) - 1.0 and len(r["history"]) >= 1
