"""The corpus used by verify: fixed, bundled, identical for every learner."""
import gzip
import os

from kdlib.sources import DATA


def _read(name):
    with gzip.open(os.path.join(DATA, name), "rt", encoding="utf-8") as f:
        return f.read()


def bundled_raw(book_id):
    """Raw Gutenberg text (as downloaded) of a bundled book: 244 or 2097."""
    with gzip.open(os.path.join(DATA, "raw", "%d.txt.gz" % book_id), "rt", encoding="utf-8") as f:
        return f.read()


def bundled_splits():
    """(train, val, test) cleaned text, split by document, from the bundled books."""
    return _read("clean_train.txt.gz"), _read("clean_val.txt.gz"), _read("clean_test.txt.gz")
