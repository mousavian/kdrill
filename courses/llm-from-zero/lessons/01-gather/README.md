# 01 - Gather data for real

## Concept

A language model is only as good as the text it reads, and the text has to come from
somewhere. Gathering sounds like "download a file", but real pipelines fail in boring
ways: servers answer 503 or 429 when busy, connections drop halfway through a body,
a mirror is down, a file changes upstream, you run the script twice and re-download
everything, or you cannot later say where a file came from.

The habits that fix this are small and worth building into every data project:

- **Be polite.** Send an honest `User-Agent` (without personal data), pause between
  requests, never hammer a server. Project Gutenberg asks bulk users to use its
  *mirrors* instead of the main site and to respect its robot policy; this course's
  pinned list points at two mirrors.
- **Retry only what can improve** (network errors, 429, 5xx) with growing waits
  (exponential backoff). Do not retry a 404 or a bad checksum.
- **Verify with a checksum.** A pinned sha256 turns "I think this is the same book"
  into a fact, and catches truncated or altered downloads.
- **Write atomically** (`.part` file, then rename) so a crash never leaves a
  half-file that looks finished.
- **Cache**, so a second run costs nothing and a flaky network does not stop work.
- **Keep a manifest**: for every file its source, licence, date, size and checksum.
  That is the start of the data card you will write in lesson 06.

The corpus of this course is nine Sherlock Holmes books by Arthur Conan Doyle (about
3.9 MB of text): one author, one voice, public domain, big enough to need cleaning and
small enough to train on a CPU.

## The situation

`data/sources.json` in your workspace lists nine books with their mirror urls and
pinned sha256 sums. `fetcher.py` has the interface; `gather.py` (finished) uses it.

## Your task

Implement the five functions in `fetcher.py` (`sha256_of`, `fetch`, `fetch_first`,
`build_manifest`, `fetch_all`; read each docstring, they list every rule). Verify
checks them offline against a local test server that misbehaves on purpose: 503s,
a dropped connection, a 404, a wrong checksum, a second run that must not download
again, a mirror that is down. It also checks the `User-Agent` and the manifest.

Then run it for real:

    make py F=gather.py        # about 20-30 s; this lesson allows the network

If the network is unavailable the course falls back to a small bundled public-domain
subset (and later lessons work offline from `~/.cache/kdrill/llm-from-zero`).

## Useful commands

- `kdrill py` with no file opens a Python shell in the course container.
- `kdrill verify`, `kdrill hint`, `kdrill reset` (your files go to `.backup/`).
- `ls -l ~/kdrill-work/llm-from-zero/data/raw`

## On a real project

Large crawls use a polite crawler with per-host rate limits, `robots.txt` handling,
resumable downloads (HTTP `Range`) and content-addressed storage. Licences matter:
"publicly available" is not "free to train on". Record the licence per source.

## Read more

- Project Gutenberg robot and mirror policy: https://www.gutenberg.org/policy/robot_access.html
- Python `urllib.request`: https://docs.python.org/3/library/urllib.request.html
- Exponential backoff (AWS Architecture Blog): https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
- Datasheets for Datasets (Gebru et al.): https://arxiv.org/abs/1803.09010
