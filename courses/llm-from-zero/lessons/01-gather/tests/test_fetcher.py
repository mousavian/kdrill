import hashlib
import json
import os
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest

import fetcher

BODY = b"It is a capital mistake to theorise before one has data.\n" * 50


class Srv:
    def __init__(self):
        self.hits = {}
        self.headers = []
        self.script = {}  # path -> list of actions, consumed in order; last repeats
        outer = self

        class H(BaseHTTPRequestHandler):
            def log_message(self, *a):
                pass

            def do_GET(self):
                outer.hits[self.path] = outer.hits.get(self.path, 0) + 1
                outer.headers.append(dict(self.headers))
                acts = outer.script.get(self.path, [("ok", BODY)])
                n = outer.hits[self.path] - 1
                kind, arg = acts[min(n, len(acts) - 1)]
                if kind == "status":
                    self.send_response(arg)
                    self.send_header("Content-Length", "0")
                    self.end_headers()
                elif kind == "short":  # promise more bytes than are sent, then hang up
                    self.send_response(200)
                    self.send_header("Content-Length", str(len(arg) * 2))
                    self.end_headers()
                    self.wfile.write(arg)
                    self.wfile.flush()
                    self.close_connection = True
                else:
                    self.send_response(200)
                    self.send_header("Content-Length", str(len(arg)))
                    self.end_headers()
                    self.wfile.write(arg)

        self.httpd = ThreadingHTTPServer(("127.0.0.1", 0), H)
        self.port = self.httpd.server_address[1]
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()

    def url(self, path="/a.txt"):
        return "http://127.0.0.1:%d%s" % (self.port, path)

    def close(self):
        self.httpd.shutdown()


@pytest.fixture()
def srv():
    s = Srv()
    yield s
    s.close()


def sha(b):
    return hashlib.sha256(b).hexdigest()


def test_sha256_of(tmp_path):
    """sha256_of returns the hex digest of a file (also for a file bigger than one chunk)"""
    p = tmp_path / "x.bin"
    data = os.urandom(300000)
    p.write_bytes(data)
    assert fetcher.sha256_of(str(p)) == sha(data)


def test_download_and_user_agent(srv, tmp_path):
    """fetch downloads the file, creates missing directories and sends a polite User-Agent"""
    dest = str(tmp_path / "deep" / "dir" / "a.txt")
    out = fetcher.fetch(srv.url(), dest, sha(BODY), sleep=lambda s: None)
    assert out == dest and open(dest, "rb").read() == BODY
    ua = srv.headers[0].get("User-Agent", "")
    assert ua == fetcher.USER_AGENT and not ua.startswith("Python-urllib"), "send the header User-Agent: USER_AGENT"
    assert not os.path.exists(dest + ".part"), "no .part file may remain after success"


def test_retries_with_backoff(srv, tmp_path):
    """503 twice then 200: the third attempt succeeds, with sleeps of backoff*2**k in between"""
    srv.script["/a.txt"] = [("status", 503), ("status", 503), ("ok", BODY)]
    sleeps = []
    dest = str(tmp_path / "a.txt")
    fetcher.fetch(srv.url(), dest, sha(BODY), retries=3, backoff=0.5, sleep=sleeps.append)
    assert srv.hits["/a.txt"] == 3
    assert sleeps == [0.5, 1.0], "expected sleeps [0.5, 1.0], got %r" % sleeps


def test_429_is_retried(srv, tmp_path):
    """HTTP 429 (too many requests) is retried like a 5xx"""
    srv.script["/a.txt"] = [("status", 429), ("ok", BODY)]
    fetcher.fetch(srv.url(), str(tmp_path / "a.txt"), None, sleep=lambda s: None)
    assert srv.hits["/a.txt"] == 2


def test_gives_up_after_retries(srv, tmp_path):
    """a server that always fails is tried exactly `retries` times, then FetchError (no sleep after the last)"""
    srv.script["/a.txt"] = [("status", 500)]
    sleeps = []
    with pytest.raises(fetcher.FetchError):
        fetcher.fetch(srv.url(), str(tmp_path / "a.txt"), None, retries=4, backoff=1, sleep=sleeps.append)
    assert srv.hits["/a.txt"] == 4
    assert len(sleeps) == 3, "sleep between attempts only: expected 3 sleeps, got %d" % len(sleeps)
    assert not (tmp_path / "a.txt").exists()


def test_404_is_not_retried(srv, tmp_path):
    """a 404 raises FetchError immediately: one request, no sleeping"""
    srv.script["/a.txt"] = [("status", 404)]
    sleeps = []
    with pytest.raises(fetcher.FetchError):
        fetcher.fetch(srv.url(), str(tmp_path / "a.txt"), None, retries=5, sleep=sleeps.append)
    assert srv.hits["/a.txt"] == 1 and sleeps == []


def test_truncated_body_is_a_network_error(srv, tmp_path):
    """a connection that dies mid-body is retried and never leaves a truncated file"""
    srv.script["/a.txt"] = [("short", BODY[:100]), ("ok", BODY)]
    dest = str(tmp_path / "a.txt")
    fetcher.fetch(srv.url(), dest, sha(BODY), sleep=lambda s: None)
    assert srv.hits["/a.txt"] == 2
    assert open(dest, "rb").read() == BODY


def test_cache_hit_makes_no_request(srv, tmp_path):
    """a file that is already there and matches its checksum is not downloaded again"""
    dest = str(tmp_path / "a.txt")
    open(dest, "wb").write(BODY)
    fetcher.fetch(srv.url(), dest, sha(BODY), sleep=lambda s: None)
    assert srv.hits == {}, "the cache was ignored"


def test_cached_file_with_wrong_checksum_is_replaced(srv, tmp_path):
    """a cached file with the wrong checksum is downloaded again and replaced"""
    dest = str(tmp_path / "a.txt")
    open(dest, "wb").write(b"corrupted")
    fetcher.fetch(srv.url(), dest, sha(BODY), sleep=lambda s: None)
    assert srv.hits["/a.txt"] == 1 and open(dest, "rb").read() == BODY


def test_checksum_mismatch(srv, tmp_path):
    """wrong bytes raise FetchError at once (no retry) and leave neither dest nor .part"""
    dest = str(tmp_path / "a.txt")
    with pytest.raises(fetcher.FetchError):
        fetcher.fetch(srv.url(), dest, sha(b"something else"), retries=3, sleep=lambda s: None)
    assert srv.hits["/a.txt"] == 1, "a checksum mismatch must not be retried"
    assert not os.path.exists(dest) and not os.path.exists(dest + ".part")


def test_fetch_first_uses_next_mirror(srv, tmp_path):
    """fetch_first moves on to the next url when a mirror is down; the error names every url when all fail"""
    srv.script["/down.txt"] = [("status", 503)]
    dest = str(tmp_path / "a.txt")
    urls = [srv.url("/down.txt"), srv.url("/a.txt")]
    fetcher.fetch_first(urls, dest, sha(BODY), retries=2, sleep=lambda s: None)
    assert open(dest, "rb").read() == BODY
    with pytest.raises(fetcher.FetchError) as ei:
        fetcher.fetch_first([srv.url("/down.txt")], str(tmp_path / "b.txt"), None, retries=1, sleep=lambda s: None)
    assert "/down.txt" in str(ei.value)


def _books(srv, n=3):
    books = []
    for i in range(n):
        body = (b"book %d " % i) * 200
        srv.script["/b%d.txt" % i] = [("ok", body)]
        books.append({"id": i, "title": "Book %d" % i, "file": "b%d.txt" % i, "sha256": sha(body),
                      "urls": [srv.url("/dead%d.txt" % i), srv.url("/b%d.txt" % i)], "licence": "PD test"})
        srv.script["/dead%d.txt" % i] = [("status", 404)]
    return books


def test_fetch_all_manifest_and_politeness(srv, tmp_path):
    """fetch_all downloads every book, waits between downloads, and writes a correct manifest.json"""
    books = _books(srv)
    waits = []
    out = str(tmp_path / "raw")
    m = fetcher.fetch_all(books, out, delay=2.5, sleep=waits.append)
    assert waits == [2.5, 2.5], "wait `delay` between downloads (not before the first): got %r" % waits
    on_disk = json.load(open(os.path.join(out, "manifest.json")))
    assert on_disk == m and len(m) == 3
    for b, e in zip(books, m):
        assert set(e) == {"title", "source", "path", "bytes", "sha256", "licence", "fetched"}
        assert e["title"] == b["title"] and e["sha256"] == b["sha256"] and e["licence"] == "PD test"
        assert e["bytes"] == os.path.getsize(os.path.join(out, b["file"]))
        assert e["source"].startswith("http://127.0.0.1:")
        assert re.fullmatch(r"\d{4}-\d\d-\d\d", e["fetched"])


def test_second_run_is_free(srv, tmp_path):
    """running fetch_all again makes no requests and no waiting; a deleted file is fetched again"""
    books = _books(srv)
    out = str(tmp_path / "raw")
    fetcher.fetch_all(books, out, sleep=lambda s: None)
    srv.hits.clear()
    waits = []
    fetcher.fetch_all(books, out, delay=3, sleep=waits.append)
    assert srv.hits == {} and waits == [], "cached files must cost no requests and no waiting"
    os.remove(os.path.join(out, "b1.txt"))
    fetcher.fetch_all(books, out, delay=3, sleep=waits.append)
    assert srv.hits.get("/b1.txt") == 1 and srv.hits.get("/b0.txt") is None
