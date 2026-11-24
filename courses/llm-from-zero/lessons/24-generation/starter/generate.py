"""Lesson 24 - generation and sampling (PyTorch). Works with any model that follows
    logits, loss = model(idx, targets=None)
and has a .block_size attribute (your gpt.py from lesson 21 does).

All logits here have shape (B, V). Not allowed: HuggingFace transformers / model.generate.
"""
import torch
import torch.nn.functional as F


def top_k_filter(logits, k):
    """Keep the k largest logits of each row, set all others to -inf. Entries tied with the k-th
    largest value stay. k None, or k >= V: return the logits unchanged. Return a new tensor."""
    # TODO
    raise NotImplementedError


def top_p_filter(logits, p):
    """Nucleus filtering. For each row: sort the probabilities (softmax of the row) in descending
    order; a token is KEPT when the cumulative probability of the tokens ranked above it is < p
    (so the token that pushes the total over p is included, and the best token is always kept).
    Everything else becomes -inf. p None or p >= 1: unchanged. Return a new tensor, with the
    original token order."""
    # TODO
    raise NotImplementedError


def apply_repetition_penalty(logits, generated, penalty):
    """For every token id that occurs in `generated` (a (B, t) LongTensor) divide its logit by
    `penalty` if the logit is positive and multiply it by `penalty` if it is negative, per row.
    penalty 1.0 or generated None: unchanged. Return a new tensor (the input is not modified)."""
    # TODO
    raise NotImplementedError


def sample_next(logits, temperature=1.0, top_k=None, top_p=None, penalty=1.0, generated=None, generator=None):
    """Choose the next token for every row. Order of operations:
    repetition penalty -> if temperature == 0: return the argmax (greedy) -> divide by temperature
    -> top-k filter -> top-p filter -> softmax -> torch.multinomial(probs, 1, generator=generator).
    Return a (B, 1) LongTensor."""
    # TODO
    raise NotImplementedError


@torch.no_grad()
def generate(model, idx, max_new_tokens, temperature=1.0, top_k=None, top_p=None, repetition_penalty=1.0,
             generator=None, eos_id=None):
    """Extend the prompt idx (B, T0) by up to max_new_tokens tokens, one at a time:
    feed the LAST model.block_size tokens, take the logits of the last position, sample_next
    (passing the whole sequence so far as `generated`), append. If eos_id is given, stop as soon
    as every row has produced eos_id among its NEW tokens. The model's train/eval mode is restored
    afterwards (generation runs in eval mode). Return the (B, T0 + n) LongTensor, prompt included."""
    # TODO
    raise NotImplementedError
