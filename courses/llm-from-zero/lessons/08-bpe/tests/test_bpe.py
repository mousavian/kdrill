import random
import re
import time

import pytest

import bpe
from bpe import BPE
from kdlib import kdtest
from kdlib.corpus import bundled_splits

EOT = "<|endoftext|>"


def ref_merge(ids, pair, new):
    out, i = [], 0
    while i < len(ids):
        if i + 1 < len(ids) and (ids[i], ids[i + 1]) == pair:
            out.append(new); i += 2
        else:
            out.append(ids[i]); i += 1
    return out


def ref_train(text, num_merges):
    """slow, simple reference trainer: same rules, no chunk counting"""
    chunks = [list(c.encode()) for c in re.findall(bpe.PRETOKEN.pattern, text)]
    merges = []
    for _ in range(num_merges):
        cnt = {}
        for ch in chunks:
            for p in zip(ch, ch[1:]):
                cnt[p] = cnt.get(p, 0) + 1
        if not cnt:
            break
        best = min(cnt, key=lambda p: (-cnt[p], p))
        if cnt[best] < 2:
            break
        merges.append(best)
        chunks = [ref_merge(ch, best, 255 + len(merges)) for ch in chunks]
    return merges


def ref_encode(text, merges):
    out = []
    for ch in re.findall(bpe.PRETOKEN.pattern, text):
        ids = list(ch.encode())
        for k, p in enumerate(merges):
            ids = ref_merge(ids, p, 256 + k)
        out += ids
    return out


def test_merge_pair():
    """merge_pair replaces non-overlapping occurrences left to right and does not modify its input"""
    ids = [1, 1, 1, 2, 1, 1]
    assert bpe.merge_pair(ids, (1, 1), 9) == [9, 1, 2, 9] and ids == [1, 1, 1, 2, 1, 1]
    assert bpe.merge_pair([1, 2, 3], (2, 3), 7) == [1, 7] and bpe.merge_pair([], (1, 2), 7) == []
    assert bpe.merge_pair([5], (5, 5), 8) == [5] and bpe.merge_pair([1, 2], (2, 1), 8) == [1, 2]


def test_count_pairs_is_weighted():
    """count_pairs weights each chunk's pairs by how often the chunk occurs"""
    c = bpe.count_pairs({(1, 2, 3): 5, (2, 3): 2, (9,): 100})
    assert c[(1, 2)] == 5 and c[(2, 3)] == 7 and (9, 9) not in c and sum(c.values()) == 12


def test_classic_example_and_tie_breaking():
    """'aaabdaaabac' learns (a,a), then (a,b) by the tie rule, then their merge; it stops when no pair repeats"""
    t = BPE.train("aaabdaaabac", 10, special_tokens=())
    assert t.merges == [(97, 97), (97, 98), (256, 257)], t.merges
    assert t.vocab_size == 259
    assert t.encode("aaabdaaabac") == [258, 100, 258, 97, 99]
    assert t.decode(t.encode("aaabdaaabac")) == "aaabdaaabac"


def test_training_matches_reference_on_real_text():
    """the learned merges equal an independent slow trainer's on a few KB of real text"""
    text = bundled_splits()[0][5000:11000]
    got = BPE.train(text, 40, special_tokens=()).merges
    assert got == ref_train(text, 40)


def test_chunk_boundaries_and_specials_are_respected():
    """no merged token crosses a pre-tokenization boundary, and special tokens are never learned from"""
    text = ("the cat sat on the mat. " * 30) + EOT + ("ab" * 40 + EOT) * 5
    t = BPE.train(text, 60, special_tokens=(EOT,))
    for k in range(len(t.merges)):
        b = t.token_bytes(256 + k)
        try:
            s = b.decode("utf-8")
        except UnicodeDecodeError:
            continue
        assert len(bpe.PRETOKEN.findall(s)) == 1, "token %r spans two chunks" % s
        assert "<" not in s and "|" not in s, "learned from a special token: %r" % s
    only = BPE.train(("ab" + EOT) * 3 + "ab", 5, special_tokens=(EOT,))
    assert only.merges == [(97, 98)] and only.vocab_size == 256 + 1 + 1


def test_round_trip_unicode_whitespace_and_empty():
    """encode/decode round-trips any text: unicode, emoji, tabs, newline runs, empty string"""
    tr = bundled_splits()[0][:30000]
    t = BPE.train(tr, 80)
    for s in ["", " ", "\n\n\n", "a\tb  c", "caf\u00e9 na\u00efve \u2603 \U0001f600 end", "Mr. Sherlock Holmes of Baker Street.\n\n",
              "1234 5678", "weird @@@ ### !!!", "\u00e9" * 5]:
        assert t.decode(t.encode(s)) == s, repr(s)
    assert t.encode("") == []
    rnd = random.Random(2)
    for _ in range(30):
        s = "".join(rnd.choice("abc de\n\u00e9\u2603!,.") for _ in range(rnd.randint(0, 80)))
        assert t.decode(t.encode(s)) == s


def test_encode_applies_earliest_merges_first():
    """encode equals applying the merges in the order they were learned, on random and real strings"""
    tr = bundled_splits()[0][:40000]
    t = BPE.train(tr, 100, special_tokens=())
    text = bundled_splits()[1][:3000]
    assert t.encode(text) == ref_encode(text, t.merges)
    rnd = random.Random(5)
    for _ in range(20):
        s = "".join(rnd.choice("the and ion er ") for _ in range(60))
        assert t.encode(s) == ref_encode(s, t.merges)


def test_special_tokens():
    """a special token is one id after all merges, appears once in the output, and decodes to its text"""
    t = BPE.train("hello world hello world " * 20, 10, special_tokens=(EOT, "<|pad|>"))
    ids = t.encode("hello" + EOT + " world<|pad|>")
    assert t.special_ids[EOT] == 256 + len(t.merges) and t.special_ids["<|pad|>"] == 256 + len(t.merges) + 1
    assert ids.count(t.special_ids[EOT]) == 1 and ids.count(t.special_ids["<|pad|>"]) == 1
    assert t.decode(ids) == "hello" + EOT + " world<|pad|>"
    assert t.encode(EOT) == [t.special_ids[EOT]]


def test_decode_edge_cases():
    """a cut multi-byte character decodes with a replacement character; unknown ids raise ValueError"""
    t = BPE.train("abab" * 10, 3, special_tokens=())
    emoji = "\U0001f600".encode()
    assert t.decode(list(emoji[:2])) == "\ufffd"
    assert t.decode(list(emoji)) == "\U0001f600"
    with pytest.raises(ValueError):
        t.decode([t.vocab_size + 5])
    assert t.token_bytes(97) == b"a"


def test_compression_and_speed():
    """300 merges on 150 KB train in a reasonable time, and encoding validation text needs far fewer tokens than bytes"""
    tr, va, _ = bundled_splits()
    t0 = time.time()
    t = BPE.train(tr[:150000], 300)
    dt = time.time() - t0
    assert dt < 40, "training took %.0f s; count chunks, not characters" % dt
    ids = t.encode(va[:50000])
    assert len(ids) < 0.62 * len(va[:50000].encode()), "only %.2f tokens per byte" % (len(ids) / len(va[:50000].encode()))
    assert t.vocab_size == 256 + len(t.merges) + 1 and len(t.merges) == 300


def test_serialisation():
    """to_dict is JSON-able and from_dict gives an identical tokenizer"""
    import json
    t = BPE.train("low lower lowest " * 30, 12)
    t2 = BPE.from_dict(json.loads(json.dumps(t.to_dict())))
    assert t2.merges == t.merges and t2.special_tokens == t.special_tokens and t2.vocab_size == t.vocab_size
    s = "lowest lower low" + EOT
    assert t2.encode(s) == t.encode(s)


def test_no_tokenizer_libraries():
    """the tokenizer is written by you: no tiktoken, tokenizers, transformers, sentencepiece, nltk"""
    kdtest.assert_no_imports("bpe", {"tiktoken", "tokenizers", "transformers", "sentencepiece", "nltk", "regex", "torch"})
