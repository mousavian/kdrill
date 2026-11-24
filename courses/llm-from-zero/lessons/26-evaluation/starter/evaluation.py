"""Lesson 26 - evaluation (PyTorch). Any model with  logits, loss = model(idx)  and .block_size works."""
import json
import math
import random
import re

import torch
import torch.nn.functional as F


@torch.no_grad()
def perplexity_on_text(model, ids, block_size=None, stride=None, batch_size=16):
    """Score a whole 1-D LongTensor of token ids, every token except the first exactly once.

    block_size defaults to model.block_size, stride to block_size. Windows start at 0, stride,
    2*stride, ... and contain up to block_size input tokens (ids[s : s + block_size]) predicting
    the next tokens (ids[s + 1 : s + block_size + 1]); the last window may be shorter. In the first
    window every position is scored; in later windows only the positions that no earlier window has
    scored yet (the last `stride` positions of a full window, fewer in the shorter last window); the
    others only serve as context.
    The model runs in eval mode with no gradients, and its previous mode is restored. Batch windows
    of equal length together if you like (batch_size), but the result must not depend on it.
    Return {"loss": mean negative log-likelihood per scored token in nats (a float),
            "tokens": number of scored tokens (== len(ids) - 1), "perplexity": exp(loss)}."""
    # TODO
    raise NotImplementedError


def bits_per_char(loss, n_tokens, n_chars):
    """Convert a per-token loss in nats to bits per character of the original text:
    total nats = loss * n_tokens; divide by n_chars * ln 2. (Comparable across tokenizers.)"""
    # TODO
    raise NotImplementedError


@torch.no_grad()
def continuation_logprob(model, prompt_ids, continuation_ids):
    """Total log-probability (natural log, a float) the model gives to `continuation_ids`
    following `prompt_ids`: sum over the continuation tokens of log p(token | everything before).
    One forward pass on prompt + continuation. ValueError if prompt + continuation is longer than
    model.block_size or either is empty."""
    # TODO
    raise NotImplementedError


def run_probes(model, encode, probes):
    """Targeted probes. `probes` is a list of dicts {"prompt": str, "good": str, "bad": [str, ...]}.
    A probe PASSES when the model gives the good continuation a higher total log-probability
    than every bad one. Encode with `encode(text) -> list of ids`.
    Return {"accuracy": share of probes passed, "details": [{"prompt", "passed", "good": logprob,
    "bad": [logprob, ...]}, ...]}."""
    # TODO
    raise NotImplementedError


def contamination(train_text, test_text, n=8):
    """How much of the test text is already in the training text. Words are
    re.findall(r"[a-z0-9']+", text.lower()). Return (rate, examples): rate is the share of the test
    text's word n-grams that occur in the train text (0.0 if the test text has none), examples the
    first up to 3 such overlapping n-grams as strings (words joined by a space), in order of
    appearance."""
    # TODO
    raise NotImplementedError


def write_side_by_side(path, prompts, outputs_a, outputs_b, name_a="A", name_b="B", seed=0):
    """Write a Markdown sheet for a human judge who must not know which model wrote what.
    For prompt i, use random.Random(seed): flip a coin per prompt (in prompt order) to decide whether
    output A is shown as "Sample 1" or "Sample 2". The file has "# Side by side", then for each
    prompt a "## Prompt <i+1>" section containing the prompt, "Sample 1" and "Sample 2" with the
    texts. Also write path + ".key.json": a JSON list, one entry per prompt, {"sample1": name,
    "sample2": name}, so the answers can be unblinded later. Return the key list."""
    # TODO
    raise NotImplementedError
