"""Lesson 02 - reference solution."""
import os
import re
from collections import Counter

BOM = b"\xef\xbb\xbf"


def split_lines(text):
    if text == "":
        return []
    parts = re.split(r"\r\n|\n|\r", text)
    if parts[-1] == "":
        parts.pop()
    return parts


def decode_bytes(raw):
    try:
        text = raw.decode("utf-8")
        enc = "utf-8"
    except UnicodeDecodeError:
        return raw.decode("latin-1"), "latin-1"
    if text.startswith("\ufeff"):
        text = text[1:]
    return text, enc


def char_inventory(text):
    return Counter(text)


def data_report(raw):
    text, enc = decode_bytes(raw)
    inv = char_inventory(text)
    crlf = raw.count(b"\r\n")
    lines = split_lines(text)
    non_ascii = sorted(((c, n) for c, n in inv.items() if ord(c) > 127), key=lambda cn: (-cn[1], cn[0]))[:10]
    ctrl = sum(n for c, n in inv.items() if (ord(c) < 32 or ord(c) == 127) and c not in "\t\n\r")
    blank = [ln.strip() == "" for ln in lines]
    run = best = 0
    for b in blank:
        run = run + 1 if b else 0
        best = max(best, run)
    return {
        "bytes": len(raw),
        "encoding": enc,
        "has_bom": raw.startswith(BOM),
        "line_endings": {"crlf": crlf, "lf": raw.count(b"\n") - crlf, "cr": raw.count(b"\r") - crlf},
        "chars": len(text),
        "lines": len(lines),
        "distinct_chars": len(inv),
        "non_ascii": non_ascii,
        "control_chars": ctrl,
        "max_line_len": max((len(ln) for ln in lines), default=0),
        "blank_line_frac": (sum(blank) / len(lines)) if lines else 0.0,
        "longest_blank_run": best,
    }


def report_dir(path):
    if not os.path.isdir(path):
        return {}
    out = {}
    for name in sorted(os.listdir(path)):
        if name.endswith(".txt"):
            with open(os.path.join(path, name), "rb") as f:
                out[name] = data_report(f.read())
    return out
