"""Lesson 14 - preference data and completion log-probabilities. Plain PyTorch."""
import torch
import torch.nn.functional as F

EOS = "<|endoftext|>"
CHATTY_MARKERS = ("Elementary", "I should say", "Why,", "You see", "game is afoot")


def is_chatty(text):
    """True when the text contains one of CHATTY_MARKERS."""
    # TODO
    raise NotImplementedError


def is_valid_pair(pair):
    """pair: a dict with "prompt", "chosen", "rejected". Valid when ALL hold:
      1. the three fields are strings that are not empty after strip();
      2. chosen.strip() != rejected.strip();
      3. the preference of this task: the chosen answer is terse (not chatty) and the rejected answer is chatty;
      4. the rejected answer contains the chosen answer as a substring (both answer the prompt; they differ in style)."""
    # TODO
    raise NotImplementedError


def clean_pairs(rows, exclude_prompts=()):
    """The valid pairs of `rows`, as new dicts with the three fields stripped, in order, with
      - a pair dropped when an earlier kept pair has the same (stripped) prompt (the first one wins),
      - a pair dropped when its (stripped) prompt is in exclude_prompts (the evaluation prompts: no leakage).
    Do the validity check on the raw row first."""
    # TODO
    raise NotImplementedError


def encode_pair(tok, pair):
    """(prompt_ids, chosen_ids, rejected_ids), each a list of ints: the prompt is "Q: " + prompt + "\\nA:", the two
    completions are " " + answer + EOS (as in lesson 05)."""
    # TODO
    raise NotImplementedError


def completion_logprobs(model, items, pad_id=0):
    """items: list of (prompt_ids, completion_ids) (lists of ints). Return a float tensor of shape (B,): for each item
    the SUM of log P(completion token | everything before it) under the model, for the completion tokens only.

    Batch the items into one forward pass: the sequence of item b is prompt + completion; inputs are seq[:-1], targets
    seq[1:], right-padded with pad_id; only the positions whose target is a completion token count (the prompt does
    not). The result must be differentiable with respect to the model's parameters and must not depend on the padding or
    on the other items in the batch. Use log_softmax over the vocabulary, not a probability product."""
    # TODO
    raise NotImplementedError


def length_gap(pairs, tok):
    """{"chosen_mean": mean number of completion tokens of the chosen answers, "rejected_mean": the same for the rejected,
    "rejected_longer": the share of pairs whose rejected completion has more tokens than the chosen one}."""
    # TODO
    raise NotImplementedError
