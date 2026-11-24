# Solution notes

`solution/fetcher.py` is a complete implementation. The ideas to compare with yours:

- **Check the cache first**, by checksum, not just by existence: a half-written or
  corrupted file must not count as "already downloaded".
- **Download to `dest + ".part"`, verify, then `os.replace`.** A crash can never leave
  a plausible-looking truncated file behind.
- **Only retry what can get better**: network errors, 429 and 5xx. A 404 will be a 404
  next time; a wrong checksum is the same bytes next time.
- **Exponential backoff** (`backoff * 2**k`) is polite to a busy server.
- **Pace yourself between books** and never hit the site when the cache has the file.
- `fetch_first` is how you use mirrors: the first url that serves a verified file wins.

Copy the file to your workspace to compare: `cp $KDRILL_HOME/courses/llm-from-zero/lessons/01-gather/solution/fetcher.py /tmp/`.
