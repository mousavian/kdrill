"""Lesson 07 - a character-level tokenizer."""
import json

PAD, UNK = 0, 1
UNK_CHAR = "\ufffd"   # what an unknown id decodes to


class CharTokenizer:
    """Maps characters to integer ids and back.

    Ids: 0 = <pad>, 1 = <unk>, then every character of the training text in sorted
    order (sorted(set(text))) from id 2 on.
    """

    def __init__(self):
        self.chars = []          # characters in id order, starting at id 2
        self.stoi = {}

    @property
    def vocab_size(self):
        """Number of ids, including <pad> and <unk>."""
        # TODO
        raise NotImplementedError

    def fit(self, text):
        """Build the vocabulary from `text` (replacing any earlier one). Return self."""
        # TODO
        raise NotImplementedError

    def encode(self, text):
        """List of Python ints. A character that is not in the vocabulary becomes UNK."""
        # TODO
        raise NotImplementedError

    def decode(self, ids):
        """Inverse of encode. UNK decodes to UNK_CHAR, PAD to "" (nothing). An id that is
        not in the vocabulary raises ValueError."""
        # TODO
        raise NotImplementedError

    def to_dict(self):
        """JSON-serialisable state: {"type": "char", "chars": [...]}"""
        # TODO
        raise NotImplementedError

    @classmethod
    def from_dict(cls, d):
        """Rebuild a tokenizer from to_dict()."""
        # TODO
        raise NotImplementedError

    def save(self, path):
        """Write to_dict() as JSON to `path`."""
        # TODO
        raise NotImplementedError

    @classmethod
    def load(cls, path):
        # TODO
        raise NotImplementedError


def unk_rate(tokenizer, text):
    """Share of the characters of `text` that encode to UNK (0.0 for empty text)."""
    # TODO
    raise NotImplementedError
