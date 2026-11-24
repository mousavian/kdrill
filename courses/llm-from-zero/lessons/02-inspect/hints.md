Decode first, then count. `raw.decode("utf-8")` raises `UnicodeDecodeError` for bytes that are not UTF-8. A UTF-8 BOM decodes to the single character `"\ufeff"` at the start; strip it from the text (and still report `has_bom` from the raw bytes).
---
Line endings come from the raw bytes: `crlf = raw.count(b"\r\n")`, then lone LFs are `raw.count(b"\n") - crlf` and lone CRs are `raw.count(b"\r") - crlf`. Everything character based comes from `Counter(text)`: distinct characters is its length, non-ASCII is a filtered, sorted list (sort key `(-count, char)`), control characters are the ones with `ord(c) < 32 or ord(c) == 127` that are not tab, newline or carriage return.
---
For the blank-line statistics walk over `split_lines(text)` once: `blank = line.strip() == ""`, keep a running count of consecutive blanks and the maximum. Guard the empty-file case (no lines: fractions 0.0, `max_line_len` 0, `max` needs `default=0`).
