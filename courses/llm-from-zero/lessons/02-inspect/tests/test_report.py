import os
import random
from collections import Counter

import pytest

import report


def test_decode_utf8_bom_and_latin1():
    """UTF-8 is decoded without its BOM; bytes that are not UTF-8 fall back to latin-1"""
    assert report.decode_bytes("h\u00e9llo".encode("utf-8")) == ("h\u00e9llo", "utf-8")
    assert report.decode_bytes(b"\xef\xbb\xbfabc") == ("abc", "utf-8")
    assert report.decode_bytes(b"caf\xe9") == ("caf\u00e9", "latin-1")
    assert report.decode_bytes(b"") == ("", "utf-8")


def test_char_inventory():
    """char_inventory counts every character"""
    inv = report.char_inventory("abca \u201cq\u201d")
    assert inv["a"] == 2 and inv["\u201c"] == 1 and inv[" "] == 1 and sum(inv.values()) == 8


def test_line_endings_exact():
    """CRLF pairs, lone LF and lone CR are counted separately (a CRLF is not an LF plus a CR)"""
    r = report.data_report(b"a\r\nb\r\nc\nd\re\n\n")
    assert r["line_endings"] == {"crlf": 2, "lf": 3, "cr": 1}, r["line_endings"]
    assert r["lines"] == 6, r["lines"]


def test_bom_and_chars():
    """a BOM is reported as has_bom and does not count as a character"""
    r = report.data_report(b"\xef\xbb\xbfab\n")
    assert r["has_bom"] is True and r["chars"] == 3 and r["distinct_chars"] == 3 and r["encoding"] == "utf-8"
    assert report.data_report(b"ab")["has_bom"] is False


def test_non_ascii_ranking():
    """non_ascii lists the 10 most frequent non-ASCII characters, most frequent first, ties by character"""
    text = "".join(chr(0x100 + i) * (20 - i) for i in range(14)) + "\u00e9\u00e9" + "plain ascii"
    r = report.data_report(text.encode("utf-8"))
    na = r["non_ascii"]
    assert len(na) == 10
    assert na[0] == (chr(0x100), 20) and na[1] == (chr(0x101), 19)
    assert all(a[1] >= b[1] for a, b in zip(na, na[1:]))
    t = report.data_report("\u00e9\u00e0\u00e8z".encode("utf-8"))["non_ascii"]
    assert t == [("\u00e0", 1), ("\u00e8", 1), ("\u00e9", 1)], t  # tie: ordered by character


def test_control_chars():
    """control characters are counted, but tab, newline and carriage return are not control characters here"""
    r = report.data_report(b"a\tb\n\x00\x01\x1b\x7f\r\nz")
    assert r["control_chars"] == 4, r["control_chars"]


def test_line_statistics():
    """max_line_len, blank_line_frac and longest_blank_run on a small text"""
    text = "abc\n\n   \n\nlonger line here\nx\n"
    r = report.data_report(text.encode())
    assert r["lines"] == 6 and r["max_line_len"] == 16
    assert abs(r["blank_line_frac"] - 3 / 6) < 1e-9
    assert r["longest_blank_run"] == 3, r["longest_blank_run"]


def test_empty_input():
    """an empty file gives zeros, not an exception"""
    r = report.data_report(b"")
    assert r["bytes"] == 0 and r["lines"] == 0 and r["max_line_len"] == 0 and r["blank_line_frac"] == 0.0
    assert r["line_endings"] == {"crlf": 0, "lf": 0, "cr": 0} and r["non_ascii"] == []


def test_exact_keys_and_random_text():
    """the report has exactly the documented keys and agrees with independent counts on random text"""
    rnd = random.Random(7)
    alphabet = "abc \n\n\r\t\u00e9\u2014\u201c\x07xyz"
    text = "".join(rnd.choice(alphabet) for _ in range(5000))
    raw = text.encode("utf-8")
    r = report.data_report(raw)
    assert set(r) == {"bytes", "encoding", "has_bom", "line_endings", "chars", "lines", "distinct_chars", "non_ascii",
                      "control_chars", "max_line_len", "blank_line_frac", "longest_blank_run"}
    assert r["bytes"] == len(raw) and r["chars"] == 5000 and r["distinct_chars"] == len(set(text))
    assert r["control_chars"] == text.count("\x07")
    crlf = text.count("\r\n")
    assert r["line_endings"]["crlf"] == crlf and r["line_endings"]["lf"] == text.count("\n") - crlf


def test_report_dir(tmp_path):
    """report_dir reports every .txt file by name, sorted, and ignores other files"""
    (tmp_path / "b.txt").write_bytes(b"x\n")
    (tmp_path / "a.txt").write_bytes(b"\xef\xbb\xbfy\r\n")
    (tmp_path / "notes.md").write_bytes(b"ignored")
    out = report.report_dir(str(tmp_path))
    assert list(out) == ["a.txt", "b.txt"] and out["a.txt"]["has_bom"] is True
    assert report.report_dir(str(tmp_path / "nope")) == {}


def test_real_books():
    """on the real files in data/raw the report agrees with independent counts"""
    d = "data/raw"
    names = [n for n in sorted(os.listdir(d)) if n.endswith(".txt")] if os.path.isdir(d) else []
    assert names, "data/raw has no .txt files (run lesson 01's gather.py, or restart this lesson)"
    out = report.report_dir(d)
    assert list(out) == names
    for n in names:
        raw = open(os.path.join(d, n), "rb").read()
        text = raw.decode("utf-8")
        if text.startswith("\ufeff"):
            text = text[1:]  # exactly one BOM is stripped; anything after it is data
        r = out[n]
        assert r["bytes"] == len(raw) and r["chars"] == len(text) and r["has_bom"] == raw.startswith(b"\xef\xbb\xbf")
        assert r["distinct_chars"] == len(Counter(text))
        assert r["line_endings"]["crlf"] == raw.count(b"\r\n")
