"""Lesson 05 - instruction (SFT) data: template, cleaning, deduplication, split, encoding."""
import random

import torch

EOS = "<|endoftext|>"


def clean_text(s):
    """Collapse every run of whitespace (spaces, tabs, newlines) to one space and strip the ends."""
    # TODO
    raise NotImplementedError


def format_example(question, answer):
    """The template. Return (prompt, completion):
         prompt     = "Q: " + question + "\\nA:"
         completion = " " + answer + EOS
    so that prompt + completion reads  'Q: What colour is the lamp?\\nA: grey<|endoftext|>'.
    The end-of-text token teaches the model to STOP; the leading space of the completion is part of the answer."""
    # TODO
    raise NotImplementedError


def clean_examples(rows, max_words=20):
    """rows: list of {"question", "answer"} (strings, possibly dirty). Return the cleaned examples, as new dicts
    {"question", "answer"}, in the order of their first occurrence. Rules, in this order:
      1. drop a row when its answer contains the end-of-text marker or a newline (in the question: a newline);
      2. clean_text() both fields;
      3. drop a row when its question or its answer is empty;
      4. drop a row when len(question.split()) + len(answer.split()) > max_words;
      5. drop a row whose cleaned question was already kept (the first one wins; the answers are not compared)."""
    # TODO
    raise NotImplementedError


def split_examples(examples, eval_fraction=0.2, seed=0):
    """Split into (train, eval). Deduplicate BEFORE splitting: raise ValueError when two examples have the same
    question (they would land on both sides), and when eval_fraction is not strictly between 0 and 1.
    n_eval = max(1, round(len(examples) * eval_fraction)); which examples go to eval is decided by
    random.Random(seed): shuffle the list of indices, the first n_eval indices are eval. Within each side keep
    the original order. Same seed, same split."""
    # TODO
    raise NotImplementedError


def encode_example(tok, question, answer):
    """(ids, prompt_len): the ids of the prompt followed by the ids of the completion, each encoded on its own
    with tok.encode (the template splits at the colon, where the tokenizer would split anyway), and the number of
    prompt tokens. The last id is the end-of-text id (tok.special_ids[EOS])."""
    # TODO
    raise NotImplementedError


def encode_all(tok, examples, block_size):
    """Encode every example; examples longer than block_size tokens are dropped. Return (items, n_dropped)
    where items is a list of (ids, prompt_len)."""
    # TODO
    raise NotImplementedError


def dataset_stats(items):
    """{"n": number of items, "mean_len": mean token count, "max_len": longest, "answer_share": the share of ALL
    tokens that belong to the completion (len(ids) - prompt_len summed, over the total length)}."""
    # TODO
    raise NotImplementedError
