"""Lesson 03 - reference solution."""
import re
import unicodedata

CHAR_MAP = {
    "\u201c": '"', "\u201d": '"', "\u201e": '"', "\u201f": '"',
    "\u2018": "'", "\u2019": "'", "\u201a": "'", "\u201b": "'",
    "\u2013": "-", "\u2014": "--", "\u2026": "...",
    "\u00a0": " ", "\u2002": " ", "\u2003": " ", "\u2009": " ", "\u202f": " ",
    "\ufeff": "", "\u200b": "", "\u200c": "", "\u200d": "", "\u2060": "",
}

_START = re.compile(r"\*\*\*\s*START OF (?:THE|THIS) PROJECT GUTENBERG EBOOK.*?\*\*\*", re.I | re.S)
_END = re.compile(r"\*\*\*\s*END OF (?:THE|THIS) PROJECT GUTENBERG EBOOK|^[ \t]*End of (?:the )?Project Gutenberg", re.I | re.M)
_CONTENTS = re.compile(r"^\s*(?:table of )?contents\.?\s*$", re.I)
_ILLUS = re.compile(r"\[Illustration(?::[^\]]*)?\]", re.I)


def fix_newlines(text):
    return text.replace("\r\n", "\n").replace("\r", "\n").replace("\ufeff", "")


def strip_gutenberg(text):
    m = _START.search(text)
    if m:
        text = text[m.end():]
    m = _END.search(text)
    if m:
        text = text[:m.start()]
    return text.strip()


def drop_contents(text):
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        if not _CONTENTS.match(lines[i]):
            i += 1
            continue
        blank, end = 0, None
        for j in range(i + 1, len(lines)):
            if lines[j].strip() == "":
                blank += 1
            else:
                if blank >= 3:
                    end = j
                    break
                blank = 0
        if end is None:
            end = i + 1
        lines = lines[:i] + lines[end:]
    return "\n".join(lines)


def drop_illustrations(text):
    out = []
    # whole-line tags first (also multi-line captions), then inline ones
    text = re.sub(r"^[ \t]*\[Illustration(?::[^\]]*)?\][ \t]*\n?", "", text, flags=re.I | re.M)
    text = re.sub(r"[ \t]*\[Illustration(?::[^\]]*)?\]", "", text, flags=re.I)
    return text


def normalize(text):
    text = unicodedata.normalize("NFC", text)
    text = "".join(CHAR_MAP.get(c, c) for c in text)
    text = "".join(" " if c == "\t" else c for c in text)
    text = "".join(c for c in text if c == "\n" or unicodedata.category(c) != "Cc")
    text = re.sub(r" {2,}", " ", text)
    text = "\n".join(line.strip() for line in text.split("\n"))
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    return text + "\n" if text else ""


def unwrap_paragraphs(text):
    paras = re.split(r"\n\s*\n", text.strip())
    paras = [" ".join(p.split()) for p in paras if p.strip()]
    return "\n\n".join(paras) + "\n" if paras else ""


def clean_book(raw):
    t = fix_newlines(raw)
    t = strip_gutenberg(t)
    t = drop_contents(t)
    t = drop_illustrations(t)
    t = normalize(t)
    return unwrap_paragraphs(t)
