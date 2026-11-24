"""Lesson 01 - reference solution."""
import datetime
import hashlib
import json
import os
import time
import urllib.error
import urllib.request

USER_AGENT = "kdrill-llm-from-zero/1.0 (educational course; polite client)"


class FetchError(Exception):
    """A file could not be fetched and verified."""


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def _cached_ok(dest, sha256):
    if not os.path.isfile(dest):
        return False
    return sha256 is None or sha256_of(dest) == sha256


def fetch(url, dest, sha256=None, retries=3, backoff=0.5, timeout=30, sleep=time.sleep):
    if _cached_ok(dest, sha256):
        return dest
    parent = os.path.dirname(dest)
    if parent:
        os.makedirs(parent, exist_ok=True)
    part = dest + ".part"
    last = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                data = resp.read()
        except urllib.error.HTTPError as e:
            if e.code == 429 or e.code >= 500:
                last = "HTTP %d" % e.code
            else:
                raise FetchError("%s: HTTP %d" % (url, e.code)) from e
        except Exception as e:  # URLError, timeouts, resets, IncompleteRead ...
            last = repr(e)
        else:
            with open(part, "wb") as f:
                f.write(data)
            if sha256 is not None and hashlib.sha256(data).hexdigest() != sha256:
                os.remove(part)
                raise FetchError("%s: checksum mismatch" % url)
            os.replace(part, dest)
            return dest
        if attempt < retries - 1:
            sleep(backoff * 2 ** attempt)
    raise FetchError("%s: gave up after %d attempts (%s)" % (url, retries, last))


def fetch_first(urls, dest, sha256=None, **kwargs):
    errors = []
    for url in urls:
        try:
            return fetch(url, dest, sha256, **kwargs)
        except FetchError as e:
            errors.append(str(e))
    raise FetchError("all mirrors failed: " + "; ".join(errors) + " [" + ", ".join(urls) + "]")


def build_manifest(entries):
    today = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    out = []
    for e in entries:
        out.append({
            "title": e["title"], "source": e["url"], "path": e["path"],
            "bytes": os.path.getsize(e["path"]), "sha256": sha256_of(e["path"]),
            "licence": e["licence"], "fetched": today,
        })
    return out


def fetch_all(books, outdir, delay=1.0, sleep=time.sleep):
    os.makedirs(outdir, exist_ok=True)
    entries, waited = [], False
    for b in books:
        dest = os.path.join(outdir, b["file"])
        cached = _cached_ok(dest, b["sha256"])
        if not cached and waited:
            sleep(delay)
        fetch_first(b["urls"], dest, b["sha256"])
        if not cached:
            waited = True
        entries.append({"title": b["title"], "url": b["urls"][0], "path": dest, "licence": b["licence"]})
    manifest = build_manifest(entries)
    with open(os.path.join(outdir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    return manifest
