"""Lesson 07 - reference solution."""
import json

PAD, UNK = 0, 1
UNK_CHAR = "\ufffd"


class CharTokenizer:
    def __init__(self):
        self.chars = []
        self.stoi = {}

    @property
    def vocab_size(self):
        return 2 + len(self.chars)

    def fit(self, text):
        self.chars = sorted(set(text))
        self.stoi = {c: i + 2 for i, c in enumerate(self.chars)}
        return self

    def encode(self, text):
        get = self.stoi.get
        return [get(c, UNK) for c in text]

    def decode(self, ids):
        out = []
        for i in ids:
            i = int(i)
            if i == PAD:
                continue
            if i == UNK:
                out.append(UNK_CHAR)
            elif 2 <= i < self.vocab_size:
                out.append(self.chars[i - 2])
            else:
                raise ValueError("id %d is not in the vocabulary" % i)
        return "".join(out)

    def to_dict(self):
        return {"type": "char", "chars": list(self.chars)}

    @classmethod
    def from_dict(cls, d):
        t = cls()
        t.chars = list(d["chars"])
        t.stoi = {c: i + 2 for i, c in enumerate(t.chars)}
        return t

    def save(self, path):
        with open(path, "w", encoding="utf-8") as f:
            json.dump(self.to_dict(), f)

    @classmethod
    def load(cls, path):
        with open(path, encoding="utf-8") as f:
            return cls.from_dict(json.load(f))


def unk_rate(tokenizer, text):
    if not text:
        return 0.0
    return sum(i == UNK for i in tokenizer.encode(text)) / len(text)
