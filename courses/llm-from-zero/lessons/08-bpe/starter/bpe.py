"""Lesson 08 - byte-pair encoding (BPE) from scratch, on UTF-8 bytes.

Ids 0..255 are the 256 byte values. Every learned merge adds one id: merge number k
(k = 0, 1, ...) creates id 256 + k. Special tokens get the ids after all merges.
"""
import re
from collections import Counter

# Pre-tokenization (given): merges never cross these chunk boundaries. A chunk is a word
# with its leading space, a number, a run of symbols, or whitespace.
PRETOKEN = re.compile(r" ?[A-Za-z]+| ?[0-9]+| ?[^\sA-Za-z0-9]+|\s+(?!\S)|\s+")


def pretokenize(text):
    """Cut text into chunks; "".join(pretokenize(t)) == t always."""
    return PRETOKEN.findall(text)


def split_on_specials(text, specials):
    """(given) Cut text around special tokens: [(piece, is_special), ...], no empty pieces."""
    if not specials:
        return [(text, False)] if text else []
    pat = "(" + "|".join(re.escape(s) for s in sorted(specials, key=len, reverse=True)) + ")"
    return [(part, i % 2 == 1) for i, part in enumerate(re.split(pat, text)) if part != ""]


def merge_pair(ids, pair, new_id):
    """Return a new list where every occurrence of the adjacent pair (a, b) in `ids` is
    replaced by new_id, scanning left to right without overlaps:
    merge_pair([1, 1, 1], (1, 1), 9) == [9, 1]"""
    # TODO
    raise NotImplementedError


def count_pairs(chunk_counts):
    """`chunk_counts` maps a chunk (a tuple of ids) to how often it occurs. Return a
    Counter: adjacent pair -> total count, each chunk's pairs weighted by its count."""
    # TODO
    raise NotImplementedError


class BPE:
    def __init__(self, merges=(), special_tokens=()):
        self.merges = [tuple(m) for m in merges]       # (left_id, right_id) in training order
        self.special_tokens = list(special_tokens)
        self.rank = {p: i for i, p in enumerate(self.merges)}
        self.special_ids = {s: 256 + len(self.merges) + i for i, s in enumerate(self.special_tokens)}
        self._cache = {}

    @property
    def vocab_size(self):
        """256 + number of merges + number of special tokens."""
        # TODO
        raise NotImplementedError

    @classmethod
    def train(cls, text, num_merges, special_tokens=("<|endoftext|>",)):
        """Learn up to `num_merges` merges from `text`.

        - Text is cut around the special tokens first; the specials themselves are never
          counted or merged. Then pretokenize every piece and count identical chunks
          (as tuples of UTF-8 byte values), so a word that occurs 5000 times is processed once.
        - Repeat: count_pairs over the chunks; take the most frequent pair (ties: the
          smallest pair, comparing left id then right id); stop when the best count is
          below 2; give it the next id, record it, and apply it to every chunk.
        - Return cls(merges, special_tokens).
        """
        # TODO
        raise NotImplementedError

    def token_bytes(self, token_id):
        """The bytes a token stands for (a special token: its UTF-8 text). ValueError for an unknown id."""
        # TODO
        raise NotImplementedError

    def _encode_chunk(self, chunk_bytes):
        """Ids of one pretokenized chunk (bytes): start from the byte values and keep
        applying the learned merge that was learned EARLIEST (lowest rank) among the
        adjacent pairs present, until none applies. Cache results in self._cache."""
        # TODO
        raise NotImplementedError

    def encode(self, text):
        """List of ids. A special token string in the text becomes its single id."""
        # TODO
        raise NotImplementedError

    def decode(self, ids):
        """Text for a list of ids. Concatenate the bytes first and decode once with
        errors="replace" (a cut multi-byte character must not raise)."""
        # TODO
        raise NotImplementedError

    def to_dict(self):
        """{"type": "bpe", "merges": [[a, b], ...], "special_tokens": [...]}"""
        # TODO
        raise NotImplementedError

    @classmethod
    def from_dict(cls, d):
        # TODO
        raise NotImplementedError
