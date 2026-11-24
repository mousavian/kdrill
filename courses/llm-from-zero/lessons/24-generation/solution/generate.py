"""Lesson 24 - reference solution."""
import torch
import torch.nn.functional as F


def top_k_filter(logits, k):
    if k is None or k >= logits.shape[-1]:
        return logits.clone()
    kth = torch.topk(logits, k, dim=-1).values[..., -1:]
    return logits.masked_fill(logits < kth, float("-inf"))


def top_p_filter(logits, p):
    if p is None or p >= 1.0:
        return logits.clone()
    sorted_logits, order = torch.sort(logits, dim=-1, descending=True)
    probs = F.softmax(sorted_logits, dim=-1)
    before = torch.cumsum(probs, dim=-1) - probs
    drop_sorted = before >= p
    drop = torch.zeros_like(drop_sorted).scatter(-1, order, drop_sorted)
    return logits.masked_fill(drop, float("-inf"))


def apply_repetition_penalty(logits, generated, penalty):
    if generated is None or penalty == 1.0:
        return logits.clone()
    out = logits.clone()
    for b in range(out.shape[0]):
        ids = torch.unique(generated[b])
        vals = out[b, ids]
        out[b, ids] = torch.where(vals > 0, vals / penalty, vals * penalty)
    return out


def sample_next(logits, temperature=1.0, top_k=None, top_p=None, penalty=1.0, generated=None, generator=None):
    logits = apply_repetition_penalty(logits, generated, penalty)
    if temperature == 0:
        return logits.argmax(dim=-1, keepdim=True)
    logits = logits / temperature
    logits = top_k_filter(logits, top_k)
    logits = top_p_filter(logits, top_p)
    probs = F.softmax(logits, dim=-1)
    return torch.multinomial(probs, 1, generator=generator)


@torch.no_grad()
def generate(model, idx, max_new_tokens, temperature=1.0, top_k=None, top_p=None, repetition_penalty=1.0,
             generator=None, eos_id=None):
    was_training = model.training
    model.eval()
    finished = torch.zeros(idx.shape[0], dtype=torch.bool)
    for _ in range(max_new_tokens):
        logits, _ = model(idx[:, -model.block_size:])
        nxt = sample_next(logits[:, -1, :], temperature, top_k, top_p, repetition_penalty, idx, generator)
        idx = torch.cat([idx, nxt], dim=1)
        if eos_id is not None:
            finished |= nxt[:, 0] == eos_id
            if bool(finished.all()):
                break
    model.train(was_training)
    return idx
