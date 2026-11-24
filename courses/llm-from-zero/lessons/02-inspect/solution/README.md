# Solution notes

`solution/report.py` is a complete implementation. Things worth noticing:

- `bytes.count(b"\r\n")` first, then subtract: a CRLF is one line ending, not one `\r` plus one `\n`.
- A BOM must be removed *before* counting characters, otherwise `\ufeff` shows up as a "character" of your text.
- `Counter` does the inventory; the other numbers are derived from it, not from a second pass.
- On the real books you should see: CRLF in some files and LF in others, a BOM in a few,
  curly quotes and em-dashes, a handful of accented letters, and a Gutenberg licence preamble
  in front of some books and none in front of others. All of that is the to-do list for lesson 03.
- One of the real books starts with *two* BOMs. Strip exactly one in `decode_bytes`; the second shows up in `char_inventory`, which is how you notice it. Lesson 03 removes `\ufeff` everywhere.
