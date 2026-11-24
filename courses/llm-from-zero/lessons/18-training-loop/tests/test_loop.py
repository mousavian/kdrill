import math

import numpy as np
import pytest
import torch
import torch.nn as nn

import loop
from kdlib import kdtest
from kdlib.corpus import bundled_splits


def test_get_batch_shapes_and_shift():
    """x and y are (batch, block) LongTensors and y is x shifted by one: the target is the next token"""
    data = torch.arange(1000)
    g = torch.Generator().manual_seed(0)
    x, y = loop.get_batch(data, 16, 8, g)
    assert x.shape == y.shape == (8, 16) and x.dtype == y.dtype == torch.long
    assert torch.equal(y, x + 1), "with data = arange the target is x + 1"
    d2 = torch.randint(0, 50, (200,))
    x, y = loop.get_batch(d2, 5, 6, torch.Generator().manual_seed(1))
    for b in range(6):
        i = next(i for i in range(len(d2) - 5) if torch.equal(d2[i:i + 5], x[b]) and torch.equal(d2[i + 1:i + 6], y[b]))


def test_get_batch_stays_inside_the_data_and_covers_it():
    """windows never run past the end, every start position can occur (including the last valid one), seeds are respected"""
    data = torch.arange(40)
    starts = set()
    g = torch.Generator().manual_seed(2)
    for _ in range(300):
        x, y = loop.get_batch(data, 10, 16, g)
        assert int(y.max()) <= 39 and int(x.min()) >= 0
        starts.update(x[:, 0].tolist())
    assert starts == set(range(30)), "start positions 0..29 are valid for a block of 10 in 40 tokens"
    a = loop.get_batch(data, 10, 4, torch.Generator().manual_seed(5))
    b = loop.get_batch(data, 10, 4, torch.Generator().manual_seed(5))
    assert torch.equal(a[0], b[0]) and not torch.equal(a[0], loop.get_batch(data, 10, 4, torch.Generator().manual_seed(6))[0])
    with pytest.raises(ValueError):
        loop.get_batch(torch.arange(10), 10, 2)


def test_evaluate_is_read_only_and_restores_the_mode():
    """evaluate learns nothing (no grads, parameters unchanged), is deterministic for a generator, and restores train/eval mode"""
    torch.manual_seed(0)
    m = loop.BigramLM(7)
    data = torch.randint(0, 7, (500,))
    before = [p.detach().clone() for p in m.parameters()]
    m.train()
    l1 = loop.evaluate(m, data, 8, 16, 5, torch.Generator().manual_seed(3))
    assert m.training is True, "evaluate must put the model back in train mode"
    l2 = loop.evaluate(m, data, 8, 16, 5, torch.Generator().manual_seed(3))
    assert l1 == l2 and isinstance(l1, float)
    m.eval()
    loop.evaluate(m, data, 8, 16, 2)
    assert m.training is False, "evaluate must leave an eval-mode model in eval mode"
    assert all(p.grad is None for p in m.parameters()), "evaluation must not create gradients"
    assert all(torch.equal(a, b) for a, b in zip(before, m.parameters()))
    # equals the mean of the batch losses
    g = torch.Generator().manual_seed(4)
    ref = np.mean([m(*loop.get_batch(data, 8, 16, g))[1].item() for _ in range(5)])
    assert loop.evaluate(m, data, 8, 16, 5, torch.Generator().manual_seed(4)) == pytest.approx(ref)


def test_training_loop_equals_a_reference_loop():
    """the final parameters equal those of a reference loop (AdamW, zero_grad, the documented seed and batches)"""
    data = torch.tensor(np.tile(np.arange(10), 60))
    val = torch.tensor(np.tile(np.arange(10), 20))
    torch.manual_seed(0); a = loop.BigramLM(10)
    torch.manual_seed(0); b = loop.BigramLM(10)
    lines = []
    hist = loop.train(a, data, val, block_size=6, batch_size=8, steps=40, lr=0.05, eval_every=10, eval_iters=3, seed=7, weight_decay=0.01, log=lines.append)
    opt = torch.optim.AdamW(b.parameters(), lr=0.05, weight_decay=0.01)
    g = torch.Generator().manual_seed(7)
    for _ in range(40):
        x, y = loop.get_batch(data, 6, 8, g)
        _, loss = b(x, y)
        opt.zero_grad(set_to_none=True)
        loss.backward()
        opt.step()
    assert torch.allclose(a.table.weight, b.table.weight, atol=1e-6), "training differs from AdamW + zero_grad + the documented batches"
    assert [h["step"] for h in hist] == [0, 10, 20, 30, 40] and len(lines) == 5
    assert set(hist[0]) == {"step", "train_loss", "val_loss"} and "step 10" in lines[1] and "val loss" in lines[1]
    assert abs(hist[0]["train_loss"] - math.log(10)) < 0.8 and hist[-1]["val_loss"] < hist[0]["val_loss"] - 0.5


class Spy(nn.Module):
    """wraps a model and records which token ids it sees in train mode and in eval mode"""
    def __init__(self, inner):
        super().__init__()
        self.inner = inner
        self.seen = {"train": [], "eval": []}

    def forward(self, idx, targets=None):
        self.seen["train" if self.training else "eval"].append((int(idx.min()), int(idx.max())))
        return self.inner(idx, targets)


def test_validation_data_never_trains_the_model():
    """token ids that exist only in the validation data are never seen by the model in train mode"""
    tr = torch.tensor(np.tile(np.arange(0, 5), 100))
    va = torch.tensor(np.tile(np.arange(5, 10), 100))
    torch.manual_seed(0)
    spy = Spy(loop.BigramLM(10))
    loop.train(spy, tr, va, block_size=4, batch_size=8, steps=30, lr=0.1, eval_every=10, eval_iters=2, log=lambda s: None)
    assert spy.seen["train"] and max(hi for _, hi in spy.seen["train"]) < 5, "validation tokens reached training"
    assert spy.seen["eval"] and max(hi for _, hi in spy.seen["eval"]) >= 5, "validation data was never evaluated"


def test_uses_adamw():
    """the optimiser is torch.optim.AdamW"""
    assert "AdamW" in kdtest.used_names("loop")


def test_real_text_bigram_trains():
    """a neural bigram on real characters trains through this loop: validation loss falls well below ln V"""
    tr, va, _ = bundled_splits()
    chars = sorted(set(tr)); stoi = {c: i for i, c in enumerate(chars)}
    enc = lambda s: torch.tensor([stoi.get(c, 0) for c in s], dtype=torch.long)
    torch.manual_seed(0)
    m = loop.BigramLM(len(chars))
    hist = loop.train(m, enc(tr), enc(va), block_size=8, batch_size=64, steps=600, lr=0.05, eval_every=300, eval_iters=10, log=lambda s: None)
    assert hist[0]["val_loss"] > math.log(len(chars)) - 0.5 and hist[-1]["val_loss"] < 3.0
