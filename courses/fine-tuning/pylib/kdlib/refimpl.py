"""Compact reference implementations used by the hidden tests as scaffolding (never imported by lessons).

When a test needs "a model that has been fine-tuned for the format task" in order to check something
else (a merge, a quantiser, a win rate), it builds it here, with plain code of its own, so that a
mistake in the learner's earlier lessons cannot make an unrelated check fail.
"""
import copy
import math
import os

import torch
import torch.nn.functional as F

from kdlib import refmodel as R
from kdlib import tasks as T

PROMPT = "Q: %s\nA:"


def load_ckpt(path):
    ck = torch.load(path, weights_only=False)
    model = R.GPT(**ck["gpt_config"])
    model.load_state_dict(ck["model_state"])
    model.eval()
    return model, R.BPE.from_dict(ck["tokenizer"])


def ref_base(name="ref_base"):
    return load_ckpt(os.path.join(T.DATA, name + ".pt"))


def ids_of(tok, text):
    return torch.tensor(tok.encode(text), dtype=torch.long)


def get_batch(data, block, bs, g):
    ix = torch.randint(0, len(data) - block - 1, (bs,), generator=g)
    return (torch.stack([data[i:i + block] for i in ix.tolist()]),
            torch.stack([data[i + 1:i + block + 1] for i in ix.tolist()]))


@torch.no_grad()
def text_loss(model, ids, window=64):
    was = model.training
    model.eval()
    tot, n = 0.0, 0
    for s in range(0, len(ids) - 1, window):
        x = ids[s:s + window][None]
        y = ids[s + 1:s + window + 1][None]
        x = x[:, :y.shape[1]]
        logits, _ = model(x)
        tot += float(F.cross_entropy(logits[0], y[0], reduction="sum"))
        n += y.shape[1]
    model.train(was)
    return tot / n


def trainable(model):
    return [p for p in model.parameters() if p.requires_grad]


def lm_finetune(model, ids, steps, lr, bs=16, block=64, seed=0, replay=None, replay_share=0.0, params=None, wd=0.0):
    g = torch.Generator().manual_seed(seed)
    opt = torch.optim.AdamW(params if params is not None else trainable(model), lr=lr, weight_decay=wd)
    model.train()
    losses = []
    for s in range(steps):
        k = int(round(replay_share * bs)) if replay is not None else 0
        x, y = get_batch(ids, block, bs - k, g)
        if k:
            x2, y2 = get_batch(replay, block, k, g)
            x, y = torch.cat([x, x2]), torch.cat([y, y2])
        _, loss = model(x, y)
        opt.zero_grad(set_to_none=True)
        loss.backward()
        opt.step()
        losses.append(loss.item())
    model.eval()
    return losses


def encode_qa(tok, q, a):
    p = tok.encode(PROMPT % q)
    c = tok.encode(" " + a + T.EOS)
    return p + c, len(p)


def sft_batch(items, pad):
    L = max(len(i) for i, _ in items) - 1
    x = torch.full((len(items), L), pad, dtype=torch.long)
    y = torch.full((len(items), L), pad, dtype=torch.long)
    m = torch.zeros(len(items), L)
    for r, (ids, pl) in enumerate(items):
        n = len(ids) - 1
        x[r, :n] = torch.tensor(ids[:-1])
        y[r, :n] = torch.tensor(ids[1:])
        m[r, pl - 1:n] = 1.0
    return x, y, m


def masked_loss(logits, y, m):
    nll = F.cross_entropy(logits.reshape(-1, logits.shape[-1]), y.reshape(-1), reduction="none").reshape(y.shape)
    return (nll * m).sum() / m.sum()


def sft_train(model, items, steps, lr, bs=16, seed=0, params=None, pad=None, wd=0.0):
    pad = model.lm_head.weight.shape[0] - 1 if pad is None else pad
    g = torch.Generator().manual_seed(seed)
    opt = torch.optim.AdamW(params if params is not None else trainable(model), lr=lr, weight_decay=wd)
    model.train()
    losses = []
    for s in range(steps):
        ix = torch.randint(0, len(items), (bs,), generator=g).tolist()
        x, y, m = sft_batch([items[i] for i in ix], pad)
        loss = masked_loss(model(x)[0], y, m)
        opt.zero_grad(set_to_none=True)
        loss.backward()
        opt.step()
        losses.append(loss.item())
    model.eval()
    return losses


@torch.no_grad()
def greedy(model, tok, prompt, max_new=24):
    eos = tok.special_ids[T.EOS]
    ids = tok.encode(prompt)
    out = []
    was = model.training
    model.eval()
    for _ in range(max_new):
        ctx = (ids + out)[-model.block_size:]
        nxt = int(model(torch.tensor([ctx]))[0][0, -1].argmax())
        if nxt == eos:
            model.train(was)
            return tok.decode(out), True
        out.append(nxt)
    model.train(was)
    return tok.decode(out), False


def qa_eval(model, tok, rows, n=None):
    rows = rows[:n] if n else rows
    fmt = exact = 0
    for r in rows:
        text, fin = greedy(model, tok, PROMPT % r["question"])
        ok = fin and text.startswith(" ") and "\n" not in text and text.strip() != ""
        fmt += ok
        exact += ok and text.strip() == r["answer"]
    return {"format": fmt / len(rows), "exact": exact / len(rows)}


def qa_items(tok, rows):
    return [encode_qa(tok, r["question"], r["answer"]) for r in rows]


def clone(model):
    for mod in model.modules():
        if hasattr(mod, "att"):
            mod.att = None
    return copy.deepcopy(model)


# ---------------------------------------------------------------- LoRA (reference, for scaffolding)
import torch.nn as nn

ATTN = ("key", "query", "value", "proj")
MLP = ("fc1", "fc2")


class RefLoRA(nn.Module):
    def __init__(self, base, r, alpha):
        super().__init__()
        self.base, self.r, self.alpha, self.scale = base, r, alpha, alpha / r
        for p in base.parameters():
            p.requires_grad = False
        self.lora_A = nn.Parameter(torch.empty(r, base.in_features))
        nn.init.kaiming_uniform_(self.lora_A, a=math.sqrt(5))
        self.lora_B = nn.Parameter(torch.zeros(base.out_features, r))

    def forward(self, x):
        return self.base(x) + self.scale * ((x @ self.lora_A.T) @ self.lora_B.T)


def ref_add_lora(model, targets=ATTN, r=8, alpha=16.0, seed=0):
    for p in model.parameters():
        p.requires_grad = False
    g = torch.manual_seed(seed)
    names = []
    for name, mod in list(model.named_modules()):
        for cname, child in list(mod.named_children()):
            if isinstance(child, nn.Linear) and cname in targets:
                setattr(mod, cname, RefLoRA(child, r, alpha))
                names.append((name + "." if name else "") + cname)
    return names


# ---------------------------------------------------------------- preferences (reference, for scaffolding)
def completion_logps(model, items, pad=0):
    """items: list of (prompt_ids, completion_ids). Tensor (B,) of the summed log-probability of each completion."""
    seqs = [(list(p) + list(c), len(p)) for p, c in items]
    x, y, m = sft_batch(seqs, pad)
    logp = F.log_softmax(model(x)[0], dim=-1).gather(-1, y[..., None])[..., 0]
    return (logp * m).sum(1)


def dpo_loss(pc, pr, rc, rr, beta):
    return -F.logsigmoid(beta * ((pc - rc) - (pr - rr))).mean()


def encode_pair(tok, p):
    pr = tok.encode(PROMPT % p["prompt"])
    return pr, tok.encode(" " + p["chosen"] + T.EOS), tok.encode(" " + p["rejected"] + T.EOS)


def pair_items(tok, pairs):
    enc = [encode_pair(tok, p) for p in pairs]
    return [(a, b) for a, b, _ in enc], [(a, c) for a, _, c in enc]


@torch.no_grad()
def ref_logps(model, tok, pairs, bs=32):
    ch, rj = pair_items(tok, pairs)
    model.eval()
    c = torch.cat([completion_logps(model, ch[i:i + bs]) for i in range(0, len(ch), bs)])
    r = torch.cat([completion_logps(model, rj[i:i + bs]) for i in range(0, len(rj), bs)])
    return c, r


def dpo_train(policy, ref, tok, pairs, steps, lr, beta=0.1, bs=16, seed=0):
    ch, rj = pair_items(tok, pairs)
    rc, rr = ref_logps(ref, tok, pairs)
    g = torch.Generator().manual_seed(seed)
    opt = torch.optim.AdamW(trainable(policy), lr=lr, weight_decay=0.0)
    policy.train()
    losses = []
    for s in range(steps):
        ix = torch.randint(0, len(pairs), (bs,), generator=g).tolist()
        pc = completion_logps(policy, [ch[i] for i in ix])
        pr = completion_logps(policy, [rj[i] for i in ix])
        loss = dpo_loss(pc, pr, rc[ix], rr[ix], beta)
        opt.zero_grad(set_to_none=True)
        loss.backward()
        opt.step()
        losses.append(loss.item())
    policy.eval()
    return losses


@torch.no_grad()
def win_rate(policy, ref, tok, pairs):
    pc, pr = ref_logps(policy, tok, pairs)
    rc, rr = ref_logps(ref, tok, pairs)
    return float((((pc - rc) - (pr - rr)) > 0).float().mean())


def chatty_rate(model, tok, rows, n=40):
    k = 0
    rows = rows[:n]
    for r in rows:
        text, fin = greedy(model, tok, PROMPT % r["question"])
        k += T.is_chatty(text)
    return k / len(rows)
