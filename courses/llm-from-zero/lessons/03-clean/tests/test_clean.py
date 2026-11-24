import os
import random
import re
import unicodedata

import clean
from kdlib.corpus import bundled_raw


def test_fix_newlines():
    """fix_newlines turns CRLF and lone CR into LF and removes every BOM character"""
    assert clean.fix_newlines("a\r\nb\rc\n\ufeffd\ufeff") == "a\nb\nc\nd"


def test_strip_gutenberg_basic():
    """header up to the START marker and footer from the END marker are removed"""
    raw = ("The Project Gutenberg eBook of X\nby Y\n\nlicence text\n\n"
           "*** START OF THE PROJECT GUTENBERG EBOOK X ***\n\n\nChapter 1\n\nIt was dark.\n\n"
           "*** END OF THE PROJECT GUTENBERG EBOOK X ***\n\nlots of licence text\n")
    assert clean.strip_gutenberg(raw) == "Chapter 1\n\nIt was dark."


def test_strip_gutenberg_variants():
    """THIS instead of THE, lower case, a marker title that runs over two lines"""
    a = "junk\n*** start of this project gutenberg ebook some\nlong title ***\nBody here.\n*** end of this project gutenberg ebook some ***\nfooter"
    assert clean.strip_gutenberg(a) == "Body here."
    b = "x\n***START OF THE PROJECT GUTENBERG EBOOK T***\nBody\n***END OF THE PROJECT GUTENBERG EBOOK T***\nz"
    assert clean.strip_gutenberg(b) == "Body"


def test_strip_gutenberg_old_footer_and_missing_markers():
    """an old-style 'End of the Project Gutenberg' footer works; no markers means the text is kept"""
    old = "*** START OF THE PROJECT GUTENBERG EBOOK T ***\nStory.\nEnd of the Project Gutenberg EBook of T, by Y\nlicence"
    assert clean.strip_gutenberg(old) == "Story."
    assert clean.strip_gutenberg("  just a text \n\n") == "just a text"
    assert clean.strip_gutenberg("*** START OF THE PROJECT GUTENBERG EBOOK T ***\nonly header") == "only header"


def test_strip_gutenberg_keeps_the_words_in_the_story():
    """the words 'Project Gutenberg' inside the story are not markers"""
    raw = ("*** START OF THE PROJECT GUTENBERG EBOOK T ***\nHe read the Project Gutenberg catalogue.\n"
           "And a line: the end of the Project Gutenberg volunteers' work.\n*** END OF THE PROJECT GUTENBERG EBOOK T ***")
    out = clean.strip_gutenberg(raw)
    assert "catalogue." in out and "volunteers' work." in out


def test_drop_contents():
    """a contents block (heading to the first gap of 3+ blank lines) disappears, the story stays"""
    t = "Title\n\nCONTENTS.\n\n I. One\n\n II. Two\n III. Three\n\n\n\nI. One\n\nOnce upon a time.\n"
    out = clean.drop_contents(t)
    assert "Two" not in out and "III" not in out and "CONTENTS" not in out
    assert out.endswith("I. One\n\nOnce upon a time.\n") and out.startswith("Title")


def test_drop_contents_every_heading():
    """every contents heading is handled, not only the first"""
    t = "Contents\nx\n\n\n\nStory one.\n\nCONTENTS\ny\n\n\n\nStory two.\n"
    out = clean.drop_contents(t)
    assert "x" not in out.split() and "y" not in out.split() and "Story one." in out and "Story two." in out


def test_drop_contents_edge_cases():
    """'Table of Contents' works; without a gap only the heading goes; sentences are left alone"""
    t = "a\ntable of contents\nx\ny\n\n\n\nbody"
    assert "x" not in clean.drop_contents(t) and "body" in clean.drop_contents(t)
    no_gap = "intro\nContents\nline one\n\nline two\n"
    assert clean.drop_contents(no_gap) == "intro\nline one\n\nline two\n"
    s = "The contents of the box were strange.\nContents of a letter.\n"
    assert clean.drop_contents(s) == s


def test_drop_illustrations():
    """[Illustration] tags vanish: alone on a line (even multi-line captions) or inside a sentence"""
    t = "Before.\n\n[Illustration]\n\nAfter.\n"
    assert clean.drop_illustrations(t) == "Before.\n\n\nAfter.\n"
    t2 = "Text\n[Illustration: Holmes and\nWatson at the door]\nMore text\n"
    assert clean.drop_illustrations(t2) == "Text\nMore text\n"
    t3 = "He ran [Illustration: a dog] away and [Illustration] hid."
    assert clean.drop_illustrations(t3) == "He ran away and hid."
    assert clean.drop_illustrations("[Footnote: kept]") == "[Footnote: kept]"


def test_normalize_chars():
    """every character in CHAR_MAP is mapped, accents are kept, text is NFC"""
    assert clean.normalize("\u201cHi,\u201d she said\u2014\u2018no\u2019\u2026") == "\"Hi,\" she said--'no'...\n"
    assert clean.normalize("a\u00a0b\u2009c\u202fd\u2003e") == "a b c d e\n"
    assert clean.normalize("na\u00efve caf\u00e9") == "na\u00efve caf\u00e9\n"
    assert clean.normalize("e\u0301") == "\u00e9\n", "NFC composes e + combining accent"
    assert clean.normalize("a\u200bb\ufeffc") == "abc\n"
    assert clean.normalize("1\u20132") == "1-2\n"


def test_normalize_whitespace_and_controls():
    """tabs become spaces, other control characters go, spaces collapse, lines are stripped, blank lines limited"""
    assert clean.normalize("a\tb\x00\x07c\x1bd") == "a bcd\n"
    assert clean.normalize("  a   b  \n   c\t\n") == "a b\nc\n"
    assert clean.normalize("a\n\n\n\n\nb\n\n\nc") == "a\n\nb\n\nc\n"
    assert clean.normalize("") == "" and clean.normalize(" \n\t\n ") == ""


def test_unwrap_paragraphs():
    """hard-wrapped lines are joined; paragraphs stay separate with one blank line"""
    t = "It was a dark\nand stormy night.\n\n\nThe rain\nfell.\n"
    assert clean.unwrap_paragraphs(t) == "It was a dark and stormy night.\n\nThe rain fell.\n"
    assert clean.unwrap_paragraphs("") == "" and clean.unwrap_paragraphs("\n\n") == ""


def test_clean_book_composite():
    """the pipeline on a messy sample: CRLF, BOM, header, contents, illustration, curly quotes, wrapping, footer"""
    raw = ("\ufeffThe Project Gutenberg eBook of A Tale\r\n\r\n*** START OF THE PROJECT GUTENBERG EBOOK A TALE ***\r\n\r\n"
           "A TALE\r\n\r\nCONTENTS\r\n\r\n I. First\r\n II. Second\r\n\r\n\r\n\r\n"
           "I.\r\n\r\n[Illustration: a house]\r\n\r\n\u201cWho\r\nis there?\u201d he asked\u2014softly.\r\n\r\n"
           "*** END OF THE PROJECT GUTENBERG EBOOK A TALE ***\r\nLicence\r\n")
    assert clean.clean_book(raw) == 'A TALE\n\nI.\n\n"Who is there?" he asked--softly.\n'


def test_clean_book_idempotent_and_robust():
    """cleaning clean text changes nothing, also on random messy input; output has no stray whitespace patterns"""
    rnd = random.Random(11)
    pieces = ["word", "Word", "\n", "\n\n", "\n\n\n\n", "\r\n", " ", "  ", "\t", "\u201c", "\u201d", "\u2014", "\u00a0",
              "\ufeff", "[Illustration]", "\x07", "caf\u00e9", ".", ",", "Chapter"]
    for _ in range(40):
        raw = "".join(rnd.choice(pieces) for _ in range(rnd.randint(0, 300)))
        out = clean.clean_book(raw)
        assert clean.clean_book(out) == out, "not idempotent for %r" % raw[:60]
        assert "\r" not in out and "\ufeff" not in out and "  " not in out and "\n\n\n" not in out and "\t" not in out
        assert out == "" or (out.endswith("\n") and not out.endswith("\n\n") and not out.startswith(("\n", " ")))
        assert all(l == l.strip() for l in out.split("\n"))


def _real_texts():
    texts = {"244": bundled_raw(244)}
    d = "data/raw"
    if os.path.isdir(d):
        for n in sorted(os.listdir(d)):
            if n.endswith(".txt") and n != "244.txt":
                with open(os.path.join(d, n), encoding="utf-8") as f:
                    texts[n] = f.read()
    return texts


def test_real_books():
    """on the real books: no Gutenberg boilerplate, no curly quotes, no control characters, most of the text kept"""
    for name, raw in _real_texts().items():
        out = clean.clean_book(raw)
        low = out.lower()
        assert "start of the project gutenberg" not in low and "end of the project gutenberg" not in low, name
        assert "\r" not in out and "\ufeff" not in out and not any(c in out for c in "\u201c\u201d\u2018\u2019\u2014"), name
        assert not any(unicodedata.category(c) == "Cc" and c != "\n" for c in out), name
        assert 0.80 < len(out) / len(raw) < 1.0, "%s keeps %.2f of the text" % (name, len(out) / len(raw))
        assert "\n\n\n" not in out and "  " not in out
        assert clean.clean_book(out) == out
        assert len(re.findall(r"Holmes", out)) > 20, "%s lost its story" % name
