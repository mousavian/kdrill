"""Lesson 15 - reference solution."""
import torch
import torch.nn.functional as F

from prefs import completion_logprobs, encode_pair


def implicit_rewards(pc, pr, rc, rr, beta=0.1):
    return beta * (pc - rc), beta * (pr - rr)


def dpo_loss(pc, pr, rc, rr, beta=0.1):
    margin = beta * ((pc - rc.detach()) - (pr - rr.detach()))
    return -F.logsigmoid(margin).mean()


def _logps(model, tok, pairs, batch_size):
    ch, rj = [], []
    for p in pairs:
        pr, c, r = encode_pair(tok, p)
        ch.append((pr, c)); rj.append((pr, r))
    return ch, rj


@torch.no_grad()
def reference_logprobs(ref_model, tok, pairs, batch_size=32):
    was = ref_model.training
    ref_model.eval()
    ch, rj = _logps(ref_model, tok, pairs, batch_size)
    rc = torch.cat([completion_logprobs(ref_model, ch[i:i + batch_size]) for i in range(0, len(ch), batch_size)])
    rr = torch.cat([completion_logprobs(ref_model, rj[i:i + batch_size]) for i in range(0, len(rj), batch_size)])
    ref_model.train(was)
    return rc, rr


def dpo_train(policy, ref_lp, tok, pairs, steps, lr, beta=0.1, batch_size=16, seed=0):
    rc, rr = ref_lp
    ch, rj = _logps(policy, tok, pairs, batch_size)
    g = torch.Generator().manual_seed(seed)
    opt = torch.optim.AdamW([p for p in policy.parameters() if p.requires_grad], lr=lr, weight_decay=0.0)
    was = policy.training
    policy.train()
    losses = []
    for _ in range(steps):
        ix = torch.randint(0, len(pairs), (batch_size,), generator=g).tolist()
        pc = completion_logprobs(policy, [ch[i] for i in ix])
        pr = completion_logprobs(policy, [rj[i] for i in ix])
        loss = dpo_loss(pc, pr, rc[ix], rr[ix], beta)
        opt.zero_grad(set_to_none=True)
        loss.backward()
        opt.step()
        losses.append(float(loss.item()))
    policy.train(was)
    return losses


@torch.no_grad()
def win_rate(policy, ref_model, tok, pairs):
    wp, wr = policy.training, ref_model.training
    policy.eval(); ref_model.eval()
    ch, rj = _logps(policy, tok, pairs, 32)
    pc, pr = completion_logprobs(policy, ch), completion_logprobs(policy, rj)
    rc, rr = completion_logprobs(ref_model, ch), completion_logprobs(ref_model, rj)
    policy.train(wp); ref_model.train(wr)
    return float((((pc - rc) - (pr - rr)) > 0).float().mean())
