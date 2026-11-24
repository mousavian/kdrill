import math

import pytest
import torch
import torch.nn as nn

import generate as G
from gpt import GPT
from kdlib import kdtest


def test_no_hf_generate():
    """sampling is written by you: no transformers library and no .generate() call"""
    kdtest.assert_no_imports("generate", {"transformers"})
    kdtest.assert_not_used("generate", {"generate_text", "GenerationMixin"})


def test_top_k_filter():
    """exactly the k largest logits survive per row (ties with the k-th stay); k >= V changes nothing"""
    x = torch.tensor([[1.0, 5.0, 3.0, 4.0, 2.0], [9.0, 9.0, 1.0, 0.0, 8.0]])
    out = G.top_k_filter(x, 2)
    assert torch.isfinite(out[0]).tolist() == [False, True, False, True, False] and out[0, 1] == 5.0
    assert torch.isfinite(out[1]).tolist() == [True, True, False, False, False]
    assert torch.equal(G.top_k_filter(x, 5), x) and torch.equal(G.top_k_filter(x, None), x) and torch.equal(G.top_k_filter(x, 99), x)
    tie = G.top_k_filter(torch.tensor([[1.0, 3.0, 3.0, 3.0]]), 2)
    assert torch.isfinite(tie).sum() == 3, "ties with the k-th value stay"
    assert x[0, 0] == 1.0, "the input must not be modified"


def test_top_p_filter():
    """the smallest set of top tokens whose probability reaches p is kept (the crossing token included), in the original order"""
    probs = torch.tensor([[0.06, 0.5, 0.04, 0.3, 0.1]])
    logits = probs.log()
    kept = lambda p: torch.isfinite(G.top_p_filter(logits, p))[0].tolist()
    assert kept(0.7) == [False, True, False, True, False]
    assert kept(0.85) == [False, True, False, True, True]
    assert kept(0.01) == [False, True, False, False, False] and kept(0.5) == [False, True, False, False, False]
    assert kept(0.51) == [False, True, False, True, False]
    assert kept(1.0) == [True] * 5 and kept(None) == [True] * 5
    two = torch.stack([probs[0].log(), torch.tensor([0.25, 0.25, 0.25, 0.2, 0.05]).log()])
    out = torch.isfinite(G.top_p_filter(two, 0.6))
    assert out[0].sum() == 2 and out[1].sum() == 3, "each row is filtered on its own"
    assert torch.allclose(G.top_p_filter(logits, 0.85)[0, 1], logits[0, 1]), "kept logits are untouched"


def test_repetition_penalty():
    """positive logits of already generated tokens are divided, negative ones multiplied; others and the input stay"""
    logits = torch.tensor([[2.0, -1.0, 4.0, 0.5], [1.0, 1.0, -2.0, 3.0]])
    gen = torch.tensor([[0, 1, 1], [3, 3, 2]])
    out = G.apply_repetition_penalty(logits, gen, 2.0)
    assert torch.allclose(out, torch.tensor([[1.0, -2.0, 4.0, 0.5], [1.0, 1.0, -4.0, 1.5]]))
    assert logits[0, 0] == 2.0
    assert torch.equal(G.apply_repetition_penalty(logits, gen, 1.0), logits) and torch.equal(G.apply_repetition_penalty(logits, None, 3.0), logits)


def freq(logits, n=20000, **kw):
    g = torch.Generator().manual_seed(0)
    out = G.sample_next(logits.repeat(n, 1), generator=g, **kw)
    assert out.shape == (n, 1) and out.dtype == torch.long
    return torch.bincount(out[:, 0], minlength=logits.shape[-1]).float() / n


def test_temperature_changes_the_distribution():
    """frequencies follow softmax(logits / temperature); temperature 0 and top_k=1 are greedy"""
    p = torch.tensor([0.7, 0.2, 0.1])
    logits = p.log()[None]
    assert torch.allclose(freq(logits, temperature=1.0), p, atol=0.015)
    sharp = p ** 2 / (p ** 2).sum()
    flat = p.sqrt() / p.sqrt().sum()
    assert torch.allclose(freq(logits, temperature=0.5), sharp, atol=0.015)
    assert torch.allclose(freq(logits, temperature=2.0), flat, atol=0.015)
    assert freq(logits, temperature=0)[0] == 1.0 and freq(logits, top_k=1, temperature=5.0)[0] == 1.0


def test_top_p_and_top_k_exclude_the_tail_when_sampling():
    """tokens outside the kept set are never sampled and the rest are renormalised"""
    p = torch.tensor([0.5, 0.3, 0.1, 0.06, 0.04])
    logits = p.log()[None]
    f = freq(logits, top_k=2)
    assert f[2:].sum() == 0 and f[0] == pytest.approx(0.625, abs=0.015)
    f = freq(logits, top_p=0.75)
    assert f[2:].sum() == 0 and f[1] == pytest.approx(0.375, abs=0.015)


def test_penalty_inside_sample_next_is_applied_before_everything():
    """with temperature 0 a repetition penalty can change the argmax"""
    logits = torch.tensor([[3.0, 2.9, 0.0]])
    assert G.sample_next(logits, temperature=0)[0, 0] == 0
    assert G.sample_next(logits, temperature=0, penalty=1.5, generated=torch.tensor([[0]]))[0, 0] == 1


class Stub(nn.Module):
    """next token is always (last + 1) % V, and the model records the length of every input"""
    def __init__(self, V=10, block_size=4):
        super().__init__()
        self.V, self.block_size, self.lens, self.dummy = V, block_size, [], nn.Parameter(torch.zeros(1))

    def forward(self, idx, targets=None):
        self.lens.append(idx.shape[1])
        logits = torch.full((idx.shape[0], idx.shape[1], self.V), -20.0)
        nxt = (idx + 1) % self.V
        logits.scatter_(2, nxt[..., None], 20.0)
        return logits, None


def test_generate_basics():
    """the prompt is kept, greedy decoding follows the model, the context is cropped to block_size, no gradients, mode restored"""
    m = Stub()
    m.train()
    out = G.generate(m, torch.tensor([[1, 2, 3], [7, 8, 9]]), 6, temperature=0)
    assert out.tolist() == [[1, 2, 3, 4, 5, 6, 7, 8, 9], [7, 8, 9, 0, 1, 2, 3, 4, 5]]
    assert max(m.lens) == 4, "only the last block_size tokens may be fed to the model, got %d" % max(m.lens)
    assert m.training is True and not out.requires_grad
    m.eval(); G.generate(m, torch.tensor([[0]]), 2, temperature=0); assert m.training is False
    assert G.generate(m, torch.tensor([[5]]), 0).tolist() == [[5]]


def test_generate_stops_at_eos():
    """with eos_id the loop stops once every row has produced it among its new tokens"""
    m = Stub(V=10, block_size=8)
    out = G.generate(m, torch.tensor([[1, 2], [3, 4]]), 20, temperature=0, eos_id=7)
    assert out.shape[1] == 7 and 7 in out[0].tolist() and 7 in out[1].tolist(), out.tolist()
    first = G.generate(m, torch.tensor([[1, 2]]), 20, temperature=0, eos_id=3)
    assert first.tolist() == [[1, 2, 3]], "a prompt token equal to eos does not count, only new tokens"


def test_generate_with_a_real_gpt_is_seeded_and_greedy_matches_argmax():
    """a GPT generates in-range ids, deterministically for a seed; temperature 0 equals the step-by-step argmax"""
    torch.manual_seed(0)
    m = GPT(20, 8, 2, 2, 16)
    prompt = torch.tensor([[1, 2, 3]])
    a = G.generate(m, prompt, 12, generator=torch.Generator().manual_seed(1), top_k=5)
    b = G.generate(m, prompt, 12, generator=torch.Generator().manual_seed(1), top_k=5)
    assert torch.equal(a, b) and a.shape == (1, 15) and int(a.max()) < 20 and not torch.equal(a, G.generate(m, prompt, 12, generator=torch.Generator().manual_seed(2), top_k=5))
    greedy = G.generate(m, prompt, 10, temperature=0)
    seq = prompt.clone()
    m.eval()
    with torch.no_grad():
        for _ in range(10):
            seq = torch.cat([seq, m(seq[:, -8:])[0][:, -1].argmax(-1, keepdim=True)], dim=1)
    assert torch.equal(greedy, seq)
