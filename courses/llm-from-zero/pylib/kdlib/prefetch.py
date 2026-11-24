"""Fill the offline cache /cache/raw with the pinned Gutenberg books.

    python -m kdlib.prefetch            (run by course/lesson setup, with network)

Every file is checked against its pinned sha256. When the network (or a mirror)
fails, the books that ship with the course (a small public-domain subset) are
used instead and the cache says so in /cache/SOURCE.txt. Never raises on a
network problem: later lessons must work offline.
"""
import gzip
import hashlib
import os
import sys
import time
import urllib.request

from kdlib.sources import DATA, load_sources

CACHE = os.environ.get("KDRILL_CACHE_MOUNT", "/cache")
UA = "kdrill-llm-from-zero/1.0 (educational course; polite client, no personal data)"
OFFLINE_MARK = ".offline-since"


def sha256(b):
    return hashlib.sha256(b).hexdigest()


def have_ok(path, want):
    try:
        with open(path, "rb") as f:
            return sha256(f.read()) == want
    except OSError:
        return False


def download(urls, want, tries=3):
    last = "no url"
    for url in urls:
        for attempt in range(tries):
            try:
                req = urllib.request.Request(url, headers={"User-Agent": UA})
                with urllib.request.urlopen(req, timeout=30) as r:
                    data = r.read()
                if sha256(data) == want:
                    return data, url
                last = "checksum mismatch from " + url
                break  # another attempt will not change the bytes
            except Exception as e:  # noqa: BLE001
                last = "%s: %s" % (url, e)
                time.sleep(1.5 * (attempt + 1))
    raise OSError(last)


def bundled(book):
    p = os.path.join(DATA, "raw", book["file"] + ".gz")
    if not os.path.exists(p):
        return None
    with gzip.open(p, "rb") as f:
        data = f.read()
    return data if sha256(data) == book["sha256"] else None


def main():
    raw = os.path.join(CACHE, "raw")
    os.makedirs(raw, exist_ok=True)
    books = load_sources()
    todo = [b for b in books if not have_ok(os.path.join(raw, b["file"]), b["sha256"])]
    if not todo:
        return 0
    mark = os.path.join(CACHE, OFFLINE_MARK)
    skip_net = os.path.exists(mark) and time.time() - os.path.getmtime(mark) < 12 * 3600
    got, fell_back, failed = 0, 0, 0
    for b in todo:
        data = None
        if not skip_net:
            try:
                data, _ = download(b["urls"], b["sha256"])
                got += 1
                time.sleep(1.0)  # be polite: one book at a time, with a pause
            except OSError as e:
                print("  could not download %s (%s); using the offline fallback" % (b["file"], e), file=sys.stderr)
                skip_net = True
                with open(mark, "w") as f:
                    f.write(str(time.time()))
        if data is None:
            data = bundled(b)
            if data is not None:
                fell_back += 1
            else:
                failed += 1
                continue
        with open(os.path.join(raw, b["file"]), "wb") as f:
            f.write(data)
    if got or fell_back:    # only say something when this run changed the cache
        with open(os.path.join(CACHE, "SOURCE.txt"), "a") as f:
            f.write("%s: downloaded %d, from the bundled fallback %d, unavailable offline %d\n"
                    % (time.strftime("%Y-%m-%d %H:%M"), got, fell_back, failed))
        print("  data cache: %d downloaded, %d from the bundled public-domain fallback, %d unavailable offline"
              % (got, fell_back, failed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
