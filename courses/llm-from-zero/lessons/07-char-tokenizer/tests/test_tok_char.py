import json
import random

import pytest

import tok_char
from tok_char import CharTokenizer
from kdlib.corpus import bundled_splits


def test_vocabulary_layout():
    """ids: 0 pad, 1 unk, then the sorted distinct characters from 2; vocab_size counts all of them"""
    t = CharTokenizer().fit("hello world")
    assert t.vocab_size == 2 + len(set("hello world"))
    assert t.encode("d e") == [2 + sorted(set("hello world")).index(c) for c in "d e"]
    assert t.encode(" ") == [2], "the space sorts first here"
    assert CharTokenizer().fit("").vocab_size == 2


def test_round_trip_random_text():
    """decode(encode(x)) == x for random text over the training alphabet, including empty text and newlines"""
    rnd = random.Random(3)
    alphabet = "abc xyz\n.,'\"-\u00e9"
    train = "".join(rnd.choice(alphabet) for _ in range(500))
    t = CharTokenizer().fit(train)
    for n in (0, 1, 2, 50, 700):
        s = "".join(rnd.choice(alphabet) for _ in range(n))
        ids = t.encode(s)
        assert len(ids) == n and all(type(i) is int for i in ids), "encode returns a list of Python ints, one per character"
        assert t.decode(ids) == s


def test_unknown_characters():
    """characters outside the vocabulary encode to UNK (1) and decode to U+FFFD; the rest is untouched"""
    t = CharTokenizer().fit("abc")
    ids = t.encode("abXc\u2603")
    assert ids[2] == 1 and ids[4] == 1 and ids[0] != 1
    assert t.decode(ids) == "ab\ufffdc\ufffd"


def test_pad_and_bad_ids():
    """PAD decodes to nothing; an id outside the vocabulary raises ValueError"""
    t = CharTokenizer().fit("abc")
    assert t.decode([0, t.encode("a")[0], 0, 0]) == "a"
    with pytest.raises(ValueError):
        t.decode([t.vocab_size])
    with pytest.raises(ValueError):
        t.decode([-1])


def test_fit_replaces_vocabulary():
    """fitting again replaces the old vocabulary and fit returns the tokenizer itself"""
    t = CharTokenizer()
    assert t.fit("abc") is t
    t.fit("xyz")
    assert t.vocab_size == 5 and t.encode("a") == [1]


def test_to_dict_from_dict_and_files(tmp_path):
    """to_dict is JSON-able and from_dict/save/load rebuild an identical tokenizer"""
    t = CharTokenizer().fit("hello, w\u00f6rld")
    d = json.loads(json.dumps(t.to_dict()))
    assert d["type"] == "char"
    t2 = CharTokenizer.from_dict(d)
    p = str(tmp_path / "tok.json")
    t.save(p)
    t3 = CharTokenizer.load(p)
    s = "hello w\u00f6rld, \u2603"
    assert t.encode(s) == t2.encode(s) == t3.encode(s) and t3.vocab_size == t.vocab_size
    assert t3.decode(t3.encode("w\u00f6rld")) == "w\u00f6rld"


def test_unk_rate():
    """unk_rate is the share of characters that become UNK"""
    t = CharTokenizer().fit("abc")
    assert tok_char.unk_rate(t, "abXY") == 0.5 and tok_char.unk_rate(t, "") == 0.0 and tok_char.unk_rate(t, "abc") == 0.0


def test_on_the_real_splits():
    """fitted on the training split, the validation and test splits have almost no unknown characters"""
    tr, va, te = bundled_splits()
    t = CharTokenizer().fit(tr)
    assert 40 < t.vocab_size < 130
    assert tok_char.unk_rate(t, va) < 0.001 and tok_char.unk_rate(t, te) < 0.001
    s = tr[1000:3000]
    assert t.decode(t.encode(s)) == s
