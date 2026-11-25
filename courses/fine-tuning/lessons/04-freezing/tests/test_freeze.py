import pytest
import torch

import freeze as fz
from kdlib import kdtest, refimpl as I, refmodel as R, tasks as T


@pytest.fixture(scope="module")
def world():
    m, tok = I.ref_base()
    return m, tok, I.ids_of(tok, T.alice("train")), I.ids_of(tok, T.alice("val"))[:4000], I.ids_of(tok, T.holmes("val"))[:4000]


def test_no_libraries():
    """plain PyTorch: no peft, trl, transformers, accelerate"""
    kdtest.assert_no_imports("freeze", {"peft", "trl", "transformers", "accelerate"})


def test_freeze_except_flags_and_names(world):
    """exactly the parameters under the given prefixes stay trainable; the names come back in model order"""
    m = I.clone(world[0])
    names = fz.freeze_except(m, ["blocks.2.", "ln_f."])
    want = [n for n, _ in m.named_parameters() if n.startswith(("blocks.2.", "ln_f."))]
    assert names == want and len(want) > 10
    for n, p in m.named_parameters():
        assert p.requires_grad == (n in want), n
    fz.unfreeze_all(m)
    assert all(p.requires_grad for p in m.parameters())


def test_freeze_except_rejects_typos(world):
    """a prefix that matches nothing is an error, and nothing is changed by the failed call"""
    m = I.clone(world[0])
    with pytest.raises(ValueError):
        fz.freeze_except(m, ["blocks.2.", "blocks.7."])
    assert all(p.requires_grad for p in m.parameters())


def test_param_report_counts(world):
    """the report counts one block as 12 C^2 + 10 C parameters, the final norm as 2 C, the tied matrix once"""
    m = I.clone(world[0])
    C = m.tok_emb.weight.shape[1]
    fz.freeze_except(m, ["blocks.1."])
    r = fz.param_report(m)
    assert r["trainable"] == R.block_param_count(C)
    assert r["total"] == m.num_params() and r["fraction"] == pytest.approx(r["trainable"] / r["total"])
    fz.freeze_except(m, ["ln_f."])
    assert fz.param_report(m)["trainable"] == 2 * C
    fz.freeze_except(m, ["tok_emb."])
    assert fz.param_report(m)["trainable"] == m.tok_emb.weight.numel(), "the tied output matrix is the same parameter"
    assert fz.last_block_prefixes(m) == ["blocks.%d." % (len(m.blocks) - 1), "ln_f."]


def test_frozen_weights_do_not_move(world):
    """after training the last block, every other tensor is bit-identical and the trained ones changed"""
    m, tok, tr, va, ov = world
    mm = I.clone(m)
    before = {k: v.clone() for k, v in mm.state_dict().items()}
    out = fz.train_subset(mm, tr, ["blocks.2.", "ln_f."], steps=8, lr=1e-3, batch_size=4, weight_decay=0.1)
    assert len(out["losses"]) == 8 and 0.2 < out["report"]["fraction"] < 0.4
    for k, v in mm.state_dict().items():
        trained = k.startswith(("blocks.2.", "ln_f."))
        assert torch.equal(v, before[k]) != trained, "%s: %s" % (k, "should have changed" if trained else "was frozen but changed")
    assert all(p.grad is None for n, p in mm.named_parameters() if not n.startswith(("blocks.2.", "ln_f.")))


def test_last_block_learns_the_style_and_forgets_less(world):
    """last block + final norm (29% of the parameters): style loss gains at least 0.25, and the original loss ends at least 0.1 below full fine-tuning's"""
    m, tok, tr, va, ov = world
    part, full = I.clone(m), I.clone(m)
    b = I.text_loss(m, va)
    r = fz.train_subset(part, tr, fz.last_block_prefixes(part), steps=150, lr=1e-3)
    I.lm_finetune(full, tr, 150, 1e-3)
    assert I.text_loss(part, va) < b - 0.25, "style loss %.3f -> %.3f" % (b, I.text_loss(part, va))
    assert I.text_loss(part, ov) < I.text_loss(full, ov) - 0.1, "original loss: frozen %.3f, full %.3f" % (I.text_loss(part, ov), I.text_loss(full, ov))
