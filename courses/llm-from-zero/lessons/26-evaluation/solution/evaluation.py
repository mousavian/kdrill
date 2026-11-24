"""Lesson 26 - reference solution."""
import json
import math
import random
import re

import torch
import torch.nn.functional as F


@torch.no_grad()
def perplexity_on_text(model, ids, block_size=None, stride=None, batch_size=16):
    block = block_size or model.block_size
    stride = stride or block
    was_training = model.training
    model.eval()
    n = len(ids)
    total, count = 0.0, 0
    s, scored_upto = 0, 0                     # targets with index <= scored_upto are already scored
    while scored_upto < n - 1:
        end = min(s + block, n - 1)            # inputs ids[s:end], targets ids[s+1:end+1]
        x = ids[s:end][None]
        y = ids[s + 1:end + 1][None]
        logits, _ = model(x)
        lp = F.log_softmax(logits[0].float(), dim=-1).gather(1, y[0][:, None])[:, 0]
        new = end - scored_upto
        lp = lp[-new:]
        total += float(-lp.sum())
        count += len(lp)
        scored_upto = end
        s += stride
    model.train(was_training)
    loss = total / count
    return {"loss": loss, "tokens": count, "perplexity": math.exp(loss)}


def bits_per_char(loss, n_tokens, n_chars):
    return loss * n_tokens / (n_chars * math.log(2))


@torch.no_grad()
def continuation_logprob(model, prompt_ids, continuation_ids):
    if len(prompt_ids) == 0 or len(continuation_ids) == 0:
        raise ValueError("prompt and continuation must not be empty")
    seq = list(prompt_ids) + list(continuation_ids)
    if len(seq) > model.block_size:
        raise ValueError("prompt + continuation longer than block_size")
    was_training = model.training
    model.eval()
    logits, _ = model(torch.tensor([seq[:-1]]))
    logp = F.log_softmax(logits[0], dim=-1)
    model.train(was_training)
    k = len(continuation_ids)
    targets = torch.tensor(seq[-k:])
    return float(logp[-k:].gather(1, targets[:, None]).sum())


def run_probes(model, encode, probes):
    details, passed = [], 0
    for p in probes:
        pid = encode(p["prompt"])
        good = continuation_logprob(model, pid, encode(p["good"]))
        bad = [continuation_logprob(model, pid, encode(b)) for b in p["bad"]]
        ok = all(good > b for b in bad)
        passed += ok
        details.append({"prompt": p["prompt"], "passed": ok, "good": good, "bad": bad})
    return {"accuracy": passed / len(probes) if probes else 0.0, "details": details}


def _grams(text, n):
    w = re.findall(r"[a-z0-9']+", text.lower())
    return [" ".join(w[i:i + n]) for i in range(len(w) - n + 1)]


def contamination(train_text, test_text, n=8):
    test = _grams(test_text, n)
    if not test:
        return 0.0, []
    ref = set(_grams(train_text, n))
    hits = [g for g in test if g in ref]
    return len(hits) / len(test), hits[:3]


def write_side_by_side(path, prompts, outputs_a, outputs_b, name_a="A", name_b="B", seed=0):
    rnd = random.Random(seed)
    key, lines = [], ["# Side by side", ""]
    for i, (p, a, b) in enumerate(zip(prompts, outputs_a, outputs_b)):
        flip = rnd.random() < 0.5
        s1, s2 = (b, a) if flip else (a, b)
        key.append({"sample1": name_b if flip else name_a, "sample2": name_a if flip else name_b})
        lines += ["## Prompt %d" % (i + 1), "", p, "", "### Sample 1", "", s1, "", "### Sample 2", "", s2, ""]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    with open(path + ".key.json", "w", encoding="utf-8") as f:
        json.dump(key, f, indent=2)
    return key
