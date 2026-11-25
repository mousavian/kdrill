import math

import pytest
import torch
import torch.nn.functional as F

import dpo as D
import prefs as P
from kdlib import kdtest, refimpl as I, tasks as T

SFT = "/kdlib/kdlib/data/ref_sft.pt"


@pytest.fixture(scope="module")
def world():
    sft, tok = I.load_ckpt(SFT)
    tr, ev = T.train_eval_qa()
    return sft, tok, T.make_pairs(tr, 11), T.make_pairs(ev, 12), ev


def test_no_libraries():
    """DPO written by hand: no trl, peft, transformers"""
    kdtest.assert_no_imports("dpo", {"trl", "peft", "transformers", "accelerate"})


def test_loss_on_known_numbers():
    """equal policy and reference give ln 2; a hand-computed margin gives softplus(-beta * margin), averaged over the batch"""
    z = torch.zeros(4)
    assert float(D.dpo_loss(z, z, z, z, 0.1)) == pytest.approx(math.log(2), abs=1e-6)
    pc, pr, rc, rr = torch.tensor([-8.0, -20.0]), torch.tensor([-30.0, -10.0]), torch.tensor([-10.0, -20.0]), torch.tensor([-27.0, -10.0])
    # margins: (2 - (-3)) = 5 and (0 - 0) = 0 ; beta 0.1 -> 0.5 and 0
    want = (math.log1p(math.exp(-0.5)) + math.log(2)) / 2
    assert float(D.dpo_loss(pc, pr, rc, rr, 0.1)) == pytest.approx(want, abs=1e-6)
    assert float(D.dpo_loss(pc, pr, rc, rr, 1.0)) == pytest.approx((math.log1p(math.exp(-5.0)) + math.log(2)) / 2, abs=1e-6)
    assert float(D.dpo_loss(pc, pr, rc, rr, 1.0)) < float(D.dpo_loss(pc, pr, rc, rr, 0.1)), "a positive margin is rewarded more at a larger beta"


def test_loss_is_stable_and_has_the_right_gradients():
    """a margin of -1000 gives a finite loss (log-sigmoid), the gradient raises the chosen log-prob and lowers the rejected one, none flows to the reference"""
    pc, pr = torch.tensor([-500.0], requires_grad=True), torch.tensor([0.0], requires_grad=True)
    rc, rr = torch.tensor([0.0], requires_grad=True), torch.tensor([-500.0], requires_grad=True)
    loss = D.dpo_loss(pc, pr, rc, rr, 1.0)
    assert math.isfinite(float(loss)) and float(loss) == pytest.approx(1000.0, rel=1e-3)
    loss.backward()
    assert float(pc.grad) < 0 and float(pr.grad) > 0, "descending must increase the chosen and decrease the rejected log-probability"
    assert rc.grad is None or float(rc.grad.abs().sum()) == 0.0
    assert rr.grad is None or float(rr.grad.abs().sum()) == 0.0
    r = D.implicit_rewards(torch.tensor([-8.0]), torch.tensor([-30.0]), torch.tensor([-10.0]), torch.tensor([-27.0]), 0.1)
    assert float(r[0]) == pytest.approx(0.2) and float(r[1]) == pytest.approx(-0.3)


def test_reference_logprobs_are_frozen_values(world):
    """the reference log-probs equal completion_logprobs of each pair, carry no gradient, and leave the model alone (mode and weights)"""
    sft, tok, tr, ev, _ = world
    m = I.clone(sft)
    m.train()
    snap = {k: v.clone() for k, v in m.state_dict().items()}
    rc, rr = D.reference_logprobs(m, tok, tr[:40], batch_size=16)
    assert rc.shape == rr.shape == (40,) and not rc.requires_grad and m.training
    assert all(torch.equal(v, snap[k]) for k, v in m.state_dict().items())
    pr, ch, rj = P.encode_pair(tok, tr[7])
    with torch.no_grad():
        assert float(rc[7]) == pytest.approx(float(P.completion_logprobs(m, [(pr, ch)])[0]), abs=1e-3)
        assert float(rr[7]) == pytest.approx(float(P.completion_logprobs(m, [(pr, rj)])[0]), abs=1e-3)


def test_training_starts_at_ln2_and_leaves_the_reference_alone(world):
    """the first loss is ln 2 (policy = reference), the reference model never changes, the policy does, the loss falls, and win_rate is 0 for identical models"""
    sft, tok, tr, ev, _ = world
    ref = I.clone(sft)
    ref_state = {k: v.clone() for k, v in ref.state_dict().items()}
    pol = I.clone(sft)
    lp = D.reference_logprobs(ref, tok, tr)
    assert D.win_rate(pol, ref, tok, ev[:30]) == 0.0
    losses = D.dpo_train(pol, lp, tok, tr, steps=25, lr=5e-5, beta=0.1, batch_size=8, seed=1)
    assert len(losses) == 25 and losses[0] == pytest.approx(math.log(2), abs=1e-3)
    assert sum(losses[-5:]) / 5 < 0.6
    assert all(torch.equal(v, ref.state_dict()[k]) for k, v in ref_state.items()), "the reference model must stay frozen"
    assert not torch.equal(pol.lm_head.weight, ref.lm_head.weight)
    a = I.clone(sft)
    b = D.dpo_train(a, lp, tok, tr, steps=3, lr=5e-5, beta=0.1, batch_size=8, seed=1)
    assert b == losses[:3], "same seed, same losses"
    pol.eval()
    assert 0.0 < D.win_rate(pol, ref, tok, ev[:30]) <= 1.0 and pol.training is False


def test_dpo_removes_the_chatty_answers(world):
    """60 steps (lr 5e-5, beta 0.1): chatty answers fall from at least 40% to at most 25% of 40 held-out prompts, the win rate on held-out pairs is at least 0.9, and the right word is still in most answers"""
    sft, tok, tr, ev_pairs, ev = world
    ref = sft
    pol = I.clone(sft)
    before_chatty = I.chatty_rate(sft, tok, ev, 40)
    has = lambda m: sum(r["answer"] in I.greedy(m, tok, I.PROMPT % r["question"])[0] for r in ev[:40]) / 40
    before_has = has(sft)
    D.dpo_train(pol, D.reference_logprobs(ref, tok, tr), tok, tr, steps=60, lr=5e-5, beta=0.1)
    after_chatty = I.chatty_rate(pol, tok, ev, 40)
    wr = D.win_rate(pol, ref, tok, ev_pairs)
    assert before_chatty >= 0.4, "the SFT model should be chatty to start with (%.2f)" % before_chatty
    assert after_chatty <= 0.25, "chatty share %.2f -> %.2f" % (before_chatty, after_chatty)
    assert wr >= 0.9, "win rate on held-out pairs %.2f" % wr
    assert has(pol) >= before_has - 0.2, "answers got worse: contain the right word %.2f -> %.2f" % (before_has, has(pol))
