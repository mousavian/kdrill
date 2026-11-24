"""Lesson 03 - clean it.

Fill in the TODOs. Try it on a real book with:  make py F=try_clean.py
"""
import re
import unicodedata

# What normalize() maps (given; the tests use exactly these).
CHAR_MAP = {
    "\u201c": '"', "\u201d": '"', "\u201e": '"', "\u201f": '"',   # curly double quotes
    "\u2018": "'", "\u2019": "'", "\u201a": "'", "\u201b": "'",   # curly single quotes
    "\u2013": "-", "\u2014": "--", "\u2026": "...",               # en dash, em dash, ellipsis
    "\u00a0": " ", "\u2002": " ", "\u2003": " ", "\u2009": " ", "\u202f": " ",  # exotic spaces
    "\ufeff": "", "\u200b": "", "\u200c": "", "\u200d": "", "\u2060": "",       # BOM, zero-width
}


def fix_newlines(text):
    """Return text with \\r\\n and lone \\r turned into \\n, and every U+FEFF removed."""
    # TODO
    raise NotImplementedError


def strip_gutenberg(text):
    """Return only the book itself, without Project Gutenberg's header and footer.

    The header ends with a marker  *** START OF THE PROJECT GUTENBERG EBOOK <title> ***
    (also "THIS PROJECT GUTENBERG EBOOK"; any letter case; the <title> can run over
    several lines before the closing ***). Drop everything up to and including it.
    The footer starts with  *** END OF THE ... PROJECT GUTENBERG EBOOK ...  or, in old
    files, a line starting "End of the Project Gutenberg" (any case). Drop everything
    from there to the end.
    A missing marker means: keep from the start / to the end. The words "Project
    Gutenberg" inside the story are NOT markers. Return the result with
    leading/trailing whitespace stripped.
    """
    # TODO
    raise NotImplementedError


def drop_contents(text):
    """Remove a table of contents.

    A contents block starts at a line that, ignoring case, spaces and one final dot,
    is "contents" or "table of contents". It runs until (not including) the first
    run of three or more consecutive blank lines after it; if there is no such
    run, remove only the heading line. Lines that merely mention contents inside a
    sentence stay. Every such heading in the text is handled, one after the other.
    (Blank means empty after strip().)
    """
    # TODO
    raise NotImplementedError


def drop_illustrations(text):
    """Remove illustration tags: "[Illustration]" and "[Illustration: caption]",
    where the caption may span several lines and runs to the first "]".
    If a tag is alone on its line(s), the whole line(s) disappear; a tag inside a
    sentence is removed from it without leaving a double space behind."""
    # TODO
    raise NotImplementedError


def normalize(text):
    """Unicode and whitespace normalisation, in this spirit:
    - unicodedata NFC, then replace every character in CHAR_MAP
    - delete control characters (category Cc) except newline; a tab becomes a space
    - collapse runs of spaces into one, strip every line on both ends
    - three or more newlines in a row become exactly two (one blank line)
    - strip the text; the result ends with a single "\\n" (empty text stays "")
    """
    # TODO
    raise NotImplementedError


def unwrap_paragraphs(text):
    """Books are hard-wrapped at about 70 characters. Join the lines of each
    paragraph (paragraphs are separated by blank lines) with single spaces, and
    separate paragraphs with exactly one blank line. Input is normalised text;
    the output ends with a single newline (empty stays "")."""
    # TODO
    raise NotImplementedError


def clean_book(raw):
    """The whole cleaning pipeline on the text of one raw book, in this order:
    fix_newlines, strip_gutenberg, drop_contents, drop_illustrations, normalize,
    unwrap_paragraphs. It must be idempotent: cleaning clean text changes nothing."""
    # TODO
    raise NotImplementedError
