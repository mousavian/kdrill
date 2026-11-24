"""Lesson 02 - look before you clean.

Fill in the TODOs, then look at your real data:  make py F=show_report.py
"""
import os
import re
from collections import Counter

BOM = b"\xef\xbb\xbf"


def split_lines(text):
    """Lines of `text`, splitting only on \\r\\n, \\n and \\r (given, do not change).
    A final line break does not create an extra empty line; "" has no lines."""
    if text == "":
        return []
    parts = re.split(r"\r\n|\n|\r", text)
    if parts[-1] == "":
        parts.pop()
    return parts


def decode_bytes(raw):
    """Return (text, encoding).

    Try UTF-8 first: encoding "utf-8", text with ONE leading BOM removed (a second one, if there is one, stays: it is data). If the bytes
    are not valid UTF-8, decode as latin-1 (which never fails): encoding "latin-1".
    """
    # TODO
    raise NotImplementedError


def char_inventory(text):
    """Return a Counter: character -> number of occurrences."""
    # TODO
    raise NotImplementedError


def data_report(raw):
    """Describe a raw file given as bytes. Return a dict with exactly these keys:

    bytes             len(raw)
    encoding          from decode_bytes
    has_bom           raw starts with the UTF-8 BOM (b"\\xef\\xbb\\xbf")
    line_endings      {"crlf": n, "lf": n, "cr": n}: count of \\r\\n pairs, of
                      \\n NOT preceded by \\r, and of \\r NOT followed by \\n
    chars             number of characters in the decoded text
    lines             len(split_lines(text))
    distinct_chars    number of different characters
    non_ascii         the 10 most frequent non-ASCII characters as a list of
                      (char, count), most frequent first, ties by character
    control_chars     number of control characters: code < 32 or == 127, except
                      \\t, \\n and \\r
    max_line_len      length of the longest line (0 for no lines)
    blank_line_frac   share of lines that are empty after .strip() (0.0 if no lines)
    longest_blank_run longest run of consecutive blank lines
    """
    # TODO
    raise NotImplementedError


def report_dir(path):
    """Return {file name: data_report(bytes)} for every *.txt file in `path`
    (sorted by name; ignore everything else). A missing directory gives {}."""
    # TODO
    raise NotImplementedError
