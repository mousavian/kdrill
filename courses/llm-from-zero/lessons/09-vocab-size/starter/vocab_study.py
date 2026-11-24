"""Lesson 09 - how big should the vocabulary be?

Uses your BPE from lesson 08. Run the study on the real data with:  make py F=vocab_report.py
"""
from bpe import BPE

SPECIALS = ("<|endoftext|>",)


def tokens_per_word(ids, text):
    """len(ids) / number of whitespace-separated words of `text` (0.0 if no words)."""
    # TODO
    raise NotImplementedError


def bytes_per_token(ids, text):
    """number of UTF-8 bytes of `text` / len(ids) (0.0 if no ids)."""
    # TODO
    raise NotImplementedError


def rare_fraction(tokenizer, ids, min_count=5):
    """Share of the LEARNED merge tokens (ids 256 .. 256 + len(merges) - 1) that occur
    fewer than `min_count` times in `ids`. 0.0 when the tokenizer has no merges.
    Such tokens cost an embedding row each but are seen too rarely to be learned well."""
    # TODO
    raise NotImplementedError


def embedding_params(vocab_size, d_model):
    """Parameters of an embedding table."""
    # TODO
    raise NotImplementedError


def study(train_text, val_text, sizes, min_count=5):
    """For every target vocabulary size (a list, ascending) measure a tokenizer trained
    on `train_text`, on `val_text`. A size s means s - 256 - len(SPECIALS) merges.

    Train ONCE with the largest size; the first k merges of that tokenizer are exactly
    the tokenizer you would get by training with k merges, so smaller sizes are
    BPE(merges[:k], SPECIALS) (a size can end up smaller if training stops early).
    Return a list of dicts, one per size, with keys:
      vocab_size, merges, tokens_per_word, bytes_per_token, rare_fraction
    (all measured by encoding val_text; rare_fraction with min_count).
    """
    # TODO
    raise NotImplementedError


def choose_size(rows, max_rare=0.25):
    """The vocab_size of the row with the largest vocab_size whose rare_fraction <=
    max_rare. If no row qualifies, the smallest vocab_size."""
    # TODO
    raise NotImplementedError
