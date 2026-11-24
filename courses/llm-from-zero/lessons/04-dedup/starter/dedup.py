"""Lesson 04 - filter and deduplicate paragraphs.

Fill in the TODOs. See what it does to the real corpus:  make py F=report_filters.py
"""
import hashlib
import re


def paragraphs(text):
    """Split `text` on blank lines (a blank line may contain spaces/tabs), strip each
    paragraph and drop empty ones. Return the list in order."""
    # TODO
    raise NotImplementedError


def norm_key(par):
    """The key that decides whether two paragraphs are EXACT duplicates:
    lower-case, then keep only letters and digits (str.isalnum). So "Hello,  World!"
    and "hello world" have the same key."""
    # TODO
    raise NotImplementedError


def exact_dedup(paras):
    """Keep the first paragraph of every norm_key, in order. Store hashes of the
    keys (hashlib), not the keys, so memory does not grow with paragraph length.
    Return (kept_list, number_removed)."""
    # TODO
    raise NotImplementedError


def shingles(par, k=5):
    """The set of word k-grams of a paragraph: words are re.findall(r"\\w+", par.lower());
    each shingle is the k consecutive words joined by one space. A paragraph with fewer
    than k words (but at least one) has a single shingle: all its words. No words: empty set."""
    # TODO
    raise NotImplementedError


def jaccard(a, b):
    """|a & b| / |a | b| for two sets; 0.0 when both are empty."""
    # TODO
    raise NotImplementedError


def near_dedup(paras, threshold=0.8, k=5):
    """Drop a paragraph when its Jaccard similarity (of k-word shingles) with a paragraph
    that was KEPT earlier is >= threshold. The earlier paragraph always wins.
    Return (kept_list, dropped) where dropped is a list of
    (index_of_dropped, index_of_the_kept_paragraph_it_matched, similarity), in input order;
    when several kept paragraphs match, report the most similar (the lowest index on a tie).

    It must scale: thousands of paragraphs in a few seconds. Comparing every pair is
    too slow; use an inverted index from shingle -> kept paragraphs that contain it, so
    only paragraphs that share at least one shingle are ever compared.
    """
    # TODO
    raise NotImplementedError


def junk_reason(par, min_chars=15, min_alpha=0.6):
    """Why a paragraph should be filtered, or None if it is fine.
    "too_short"  if len(par) < min_chars
    "low_alpha"  otherwise, if letters make up less than min_alpha of all characters
    """
    # TODO
    raise NotImplementedError


def filter_and_dedup(paras, min_chars=15, min_alpha=0.6, threshold=0.8, k=5):
    """The whole step, in this order: junk filter, exact_dedup, near_dedup.
    Return (kept_list, stats) with stats a dict of ints:
    input, too_short, low_alpha, exact_duplicates, near_duplicates, kept
    (input == too_short + low_alpha + exact_duplicates + near_duplicates + kept)."""
    # TODO
    raise NotImplementedError
