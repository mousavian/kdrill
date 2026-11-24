"""Lesson 01 - gather data for real.

Fill in every TODO. The real download is done by gather.py (already written):

    make py F=gather.py        # needs the network; verify itself works offline
"""
import hashlib
import json
import os
import time
import urllib.request

# Identify yourself honestly and politely; never put personal data in here.
USER_AGENT = "kdrill-llm-from-zero/1.0 (educational course; polite client)"


class FetchError(Exception):
    """A file could not be fetched and verified."""


def sha256_of(path):
    """Return the hex sha256 of the file at `path` (read it in chunks)."""
    # TODO
    raise NotImplementedError


def fetch(url, dest, sha256=None, retries=3, backoff=0.5, timeout=30, sleep=time.sleep):
    """Download `url` to the file `dest` and return `dest`.

    Rules (all of them are checked):
    - Cache: if `dest` exists and (sha256 is None or it matches), return `dest`
      without making any request. A cached file with the WRONG checksum is
      downloaded again and replaced.
    - Send the header User-Agent: USER_AGENT.
    - At most `retries` attempts in total. Retry on network errors (timeouts,
      connection resets, a body that ends early) and on HTTP 429 and 5xx. Between
      two attempts call sleep(backoff * 2**k) where k = 0, 1, ... (no sleep after
      the last attempt).
    - Any other HTTP error (404, 403, ...) is not retried: raise FetchError.
    - Write atomically: download into dest + ".part", verify, then os.replace.
    - If `sha256` is given and the bytes do not match, raise FetchError at once
      (no retry) and leave neither `dest` nor the .part file behind.
    - Create the parent directory of `dest` if needed.
    """
    # TODO
    raise NotImplementedError


def fetch_first(urls, dest, sha256=None, **kwargs):
    """Try each url in order (mirrors) with fetch(); return dest for the first
    that works. If all fail raise FetchError whose message names every url."""
    # TODO
    raise NotImplementedError


def build_manifest(entries):
    """Describe downloaded files.

    `entries` is a list of dicts with keys: title, url, path, licence.
    Return a list of dicts, same order, each with exactly the keys
    title, source (the url), path, bytes (file size), sha256 (of the file),
    licence and fetched (today's date in UTC, "YYYY-MM-DD").
    """
    # TODO
    raise NotImplementedError


def fetch_all(books, outdir, delay=1.0, sleep=time.sleep):
    """Fetch every book into `outdir` and write `outdir/manifest.json`.

    `books` is a list of dicts like the ones in data/sources.json: id, title,
    file, sha256, urls (mirrors, in order of preference), licence.
    - Each book goes to outdir/<file>, verified against its sha256, using
      fetch_first with the book's urls.
    - Be polite: call sleep(delay) between two books that actually needed a
      download. Cache hits make no request, so they do not wait.
    - manifest.json holds build_manifest(...) (JSON, indent 2); `source` is the
      url that served the file (the first url is fine for cached files).
    Return the manifest list.
    """
    # TODO
    raise NotImplementedError
