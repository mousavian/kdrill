"""Lesson 08 - reference solution."""
import re
from collections import Counter

PRETOKEN = re.compile(r" ?[A-Za-z]+| ?[0-9]+| ?[^\sA-Za-z0-9]+|\s+(?!\S)|\s+")


def pretokenize(text):
    return PRETOKEN.findall(text)


def split_on_specials(text, specials):
    if not specials:
        return [(text, False)] if text else []
    pat = "(" + "|".join(re.escape(s) for s in sorted(specials, key=len, reverse=True)) + ")"
    return [(part, i % 2 == 1) for i, part in enumerate(re.split(pat, text)) if part != ""]


def merge_pair(ids, pair, new_id):
    out, i, n = [], 0, len(ids)
    a, b = pair
    while i < n:
        if i < n - 1 and ids[i] == a and ids[i + 1] == b:
            out.append(new_id)
            i += 2
        else:
            out.append(ids[i])
            i += 1
    return out


def count_pairs(chunk_counts):
    pc = Counter()
    for chunk, c in chunk_counts.items():
        for pair in zip(chunk, chunk[1:]):
            pc[pair] += c
    return pc


class BPE:
    def __init__(self, merges=(), special_tokens=()):
        self.merges = [tuple(m) for m in merges]
        self.special_tokens = list(special_tokens)
        self.rank = {p: i for i, p in enumerate(self.merges)}
        self.special_ids = {s: 256 + len(self.merges) + i for i, s in enumerate(self.special_tokens)}
        self._cache = {}
        self._bytes = {i: bytes([i]) for i in range(256)}
        for k, (a, b) in enumerate(self.merges):
            self._bytes[256 + k] = self._bytes[a] + self._bytes[b]
        for s, i in self.special_ids.items():
            self._bytes[i] = s.encode("utf-8")

    @property
    def vocab_size(self):
        return 256 + len(self.merges) + len(self.special_tokens)

    @classmethod
    def train(cls, text, num_merges, special_tokens=("<|endoftext|>",)):
        counts = Counter()
        for piece, is_special in split_on_specials(text, special_tokens):
            if is_special:
                continue
            for chunk in pretokenize(piece):
                counts[tuple(chunk.encode("utf-8"))] += 1
        merges = []
        for _ in range(num_merges):
            pc = count_pairs(counts)
            if not pc:
                break
            pair, n = max(pc.items(), key=lambda kv: (kv[1], -kv[0][0], -kv[0][1]))
            if n < 2:
                break
            new_id = 256 + len(merges)
            merges.append(pair)
            new_counts = Counter()
            for chunk, c in counts.items():
                new_counts[tuple(merge_pair(chunk, pair, new_id))] += c
            counts = new_counts
        return cls(merges, special_tokens)

    def token_bytes(self, token_id):
        try:
            return self._bytes[int(token_id)]
        except KeyError:
            raise ValueError("unknown token id %r" % (token_id,)) from None

    def _encode_chunk(self, chunk_bytes):
        hit = self._cache.get(chunk_bytes)
        if hit is not None:
            return hit
        ids = list(chunk_bytes)
        while len(ids) >= 2:
            best = min(((self.rank.get(p, 1 << 60), p) for p in zip(ids, ids[1:])), key=lambda rp: rp[0])
            if best[0] == 1 << 60:
                break
            ids = merge_pair(ids, best[1], 256 + best[0])
        self._cache[chunk_bytes] = ids
        return ids

    def encode(self, text):
        out = []
        for piece, is_special in split_on_specials(text, self.special_tokens):
            if is_special:
                out.append(self.special_ids[piece])
            else:
                for chunk in pretokenize(piece):
                    out.extend(self._encode_chunk(chunk.encode("utf-8")))
        return out

    def decode(self, ids):
        return b"".join(self.token_bytes(i) for i in ids).decode("utf-8", errors="replace")

    def to_dict(self):
        return {"type": "bpe", "merges": [list(m) for m in self.merges], "special_tokens": list(self.special_tokens)}

    @classmethod
    def from_dict(cls, d):
        return cls(d["merges"], d["special_tokens"])
