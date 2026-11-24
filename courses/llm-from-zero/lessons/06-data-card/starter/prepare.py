"""Lesson 06 - the whole data pipeline and the data card.

Uses your own clean.py (lesson 03), dedup.py (04) and split.py (05).
Run it on the real corpus:  make py F=prepare_run.py
"""
import hashlib
import os

from clean import clean_book
from dedup import filter_and_dedup, paragraphs
from split import ngram_overlap, oov_rate, split_documents, words, write_splits

# Write these yourself, from what you learned about THIS corpus (not generic text).
# At least three bullets, each at least 40 characters, none containing "TODO".
LIMITATIONS = [
    "TODO: who wrote the text, in which period, in which language and register",
    "TODO: what the cleaning removed or changed that could matter",
    "TODO: what the model trained on this will and will not be good at",
]


def build_dataset(raw_dir, out_dir, seed=0):
    """Build the dataset from the *.txt files in `raw_dir` (UTF-8; ignore other files).

    1. Read every file (sorted by name) and clean it with clean_book.
    2. Take the paragraphs of all documents in that order and run ONE global
       filter_and_dedup (default thresholds) over all of them, so a paragraph that
       appears in two books survives only in the first. Hint: the kept list is a
       subsequence of the input; walk both to find out which document each kept
       paragraph belongs to. A document's text is its surviving paragraphs joined by
       a blank line.
    3. split_documents(docs, seed=seed) and write_splits(docs, assignment, out_dir):
       out_dir/train.txt, val.txt, test.txt and splits.json.
    4. Write out_dir/DATA_CARD.md with make_card(stats).
    Return `stats`, a dict:
      sources      list of {"file", "bytes", "sha256"} of the RAW files, sorted by file
      raw_chars    total characters of the decoded raw files
      filters      the stats dict returned by filter_and_dedup
      splits       {"train"|"val"|"test": {"documents": [file names], "chars": characters
                   in the written file, "words": len(words(file text)),
                   "paragraphs": number of blank-line separated blocks in the file}}
      clean_chars  characters of the three written files together
      distinct_chars  number of different characters in the three files together
      leakage      {"oov_val", "oov_test", "overlap_val", "overlap_test"}: oov_rate and
                   8-gram ngram_overlap of val/test against the train file
    The same input and seed must give byte-identical files. Never modify raw files.
    """
    # TODO
    raise NotImplementedError


def make_card(stats):
    """Return the data card as Markdown with these sections, in this order
    (the headings must be exactly these):

    # Data card
    ## Sources        a table: file, bytes, sha256 of every raw file
    ## Licence        the texts are public domain in the USA and distributed by Project
                      Gutenberg under its licence (say so, in your words)
    ## Processing     what the pipeline did, with the numbers: raw characters, how many
                      paragraphs were removed as too short / low alpha / exact duplicates /
                      near duplicates, how many were kept
    ## Splits         a table: split, documents, characters, words, paragraphs, and the
                      OOV rate and 8-gram overlap of val and test against train
    ## Statistics     total characters, distinct characters
    ## Known limitations and biases   one "- " bullet per entry of LIMITATIONS

    Every integer in `stats` (sizes, counts) and every sha256 must appear in the card as plain
    digits (no thousands separators); the four OOV / overlap values must appear too, with at
    least 2 decimals.
    """
    # TODO
    raise NotImplementedError
