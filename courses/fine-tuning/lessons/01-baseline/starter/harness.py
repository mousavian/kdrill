"""Lesson 01 - the evaluation harness used by every later lesson.

You measure the model on three things: how well it predicts held-out text of the NEW style (style loss), how
well it still predicts text of its ORIGINAL kind (orig loss, to see what fine-tuning breaks), and whether it
answers questions in a fixed format (format accuracy) and correctly (exact match).
"""
import json
import os

import torch
import torch.nn.functional as F

PROMPT = "Q: {q}\nA:"
EOS = "<|endoftext|>"


@torch.no_grad()
def text_loss(model, ids, window=None):
    """Mean negative log-likelihood (nats per token) of a long 1-D LongTensor of token ids.

    Cut `ids` into consecutive non-overlapping windows of `window` input tokens (default model.block_size);
    for the window starting at s the inputs are ids[s:s+window] and the targets ids[s+1:s+window+1] (the last
    window is shorter; every token except the very first is predicted exactly once). Return the mean over ALL
    targets (not the mean of per-window means). Put the model in eval mode for the measurement and restore the
    mode it had before. ids with fewer than two tokens: raise ValueError."""
    # TODO
    raise NotImplementedError


@torch.no_grad()
def complete(model, tok, prompt, max_new_tokens=24):
    """Greedy completion. Encode `prompt` (a string), then repeatedly append the argmax token of the last
    position, feeding the model at most its last model.block_size tokens. Stop when the end-of-text token
    (tok.special_ids[EOS]) is chosen (it is not part of the output) or after max_new_tokens tokens.
    Return (text, finished): the decoded generated tokens and whether the end-of-text token was produced.
    Eval mode during the call, previous mode restored."""
    # TODO
    raise NotImplementedError


def format_ok(text, finished):
    """True when a completion has the answer format: it finished with the end-of-text token, starts with a
    space (as in 'A: grey'), has some non-space text and no newline."""
    # TODO
    raise NotImplementedError


def exact_match(text, answer):
    """True when the completion is exactly ' ' + answer."""
    # TODO
    raise NotImplementedError


def evaluate_qa(model, tok, rows, max_new_tokens=24):
    """rows: list of {"question", "answer"}. Complete PROMPT.format(q=question) for every row with complete()
    (call it through this module's name `complete`). Return {"format": share of rows whose completion passes
    format_ok, "exact": share that pass format_ok AND exact_match, "n": number of rows}."""
    # TODO
    raise NotImplementedError


def evaluate(model, tok, style_ids, orig_ids, qa_rows):
    """The numbers of the course: {"style_loss": text_loss on style_ids, "orig_loss": text_loss on orig_ids,
    "format": ..., "exact": ..., "n_qa": len(qa_rows)}  (the last three from evaluate_qa)."""
    # TODO
    raise NotImplementedError


def write_results(path, results):
    """Write a dict of numbers as JSON (sorted keys, indent 2, trailing newline), creating the folder."""
    # TODO
    raise NotImplementedError


def read_results(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)
