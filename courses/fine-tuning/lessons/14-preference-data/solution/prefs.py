"""Lesson 14 - reference solution."""
import torch
import torch.nn.functional as F

EOS = "<|endoftext|>"
CHATTY_MARKERS = ("Elementary", "I should say", "Why,", "You see", "game is afoot")


def is_chatty(text):
    return any(m in text for m in CHATTY_MARKERS)


def is_valid_pair(pair):
    try:
        p, c, r = pair["prompt"], pair["chosen"], pair["rejected"]
    except (KeyError, TypeError):
        return False
    if not all(isinstance(x, str) and x.strip() for x in (p, c, r)):
        return False
    c, r = c.strip(), r.strip()
    return c != r and not is_chatty(c) and is_chatty(r) and c in r


def clean_pairs(rows, exclude_prompts=()):
    exclude = {e.strip() for e in exclude_prompts}
    seen, out = set(), []
    for row in rows:
        if not is_valid_pair(row):
            continue
        p = row["prompt"].strip()
        if p in seen or p in exclude:
            continue
        seen.add(p)
        out.append({"prompt": p, "chosen": row["chosen"].strip(), "rejected": row["rejected"].strip()})
    return out


def encode_pair(tok, pair):
    prompt = tok.encode("Q: " + pair["prompt"] + "\nA:")
    return prompt, tok.encode(" " + pair["chosen"] + EOS), tok.encode(" " + pair["rejected"] + EOS)


def completion_logprobs(model, items, pad_id=0):
    seqs = [list(p) + list(c) for p, c in items]
    L = max(len(s) for s in seqs) - 1
    x = torch.full((len(seqs), L), pad_id, dtype=torch.long)
    y = torch.full((len(seqs), L), pad_id, dtype=torch.long)
    mask = torch.zeros(len(seqs), L)
    for b, ((p, c), s) in enumerate(zip(items, seqs)):
        n = len(s) - 1
        t = torch.tensor(s, dtype=torch.long)
        x[b, :n], y[b, :n] = t[:-1], t[1:]
        mask[b, len(p) - 1:n] = 1.0
    logp = F.log_softmax(model(x)[0], dim=-1).gather(-1, y[..., None])[..., 0]
    return (logp * mask).sum(dim=1)


def length_gap(pairs, tok):
    cl, rl = [], []
    for p in pairs:
        _, c, r = encode_pair(tok, p)
        cl.append(len(c)); rl.append(len(r))
    n = len(pairs)
    return {"chosen_mean": sum(cl) / n, "rejected_mean": sum(rl) / n, "rejected_longer": sum(1 for a, b in zip(cl, rl) if b > a) / n}
