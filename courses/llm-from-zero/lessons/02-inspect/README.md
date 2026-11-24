# 02 - Look before you clean

## Concept

Before you write a single cleaning rule, **look at the data**. Most "model problems"
are data problems, and most data problems are visible in ten minutes with a few
counters: what encoding is this, are there byte-order marks, which line endings, which
characters exist at all, how long are the lines, how much of the file is blank?

Text arrives in more shapes than you expect. Files can be UTF-8, Latin-1 or something
older; Windows files end lines with `\r\n`, Unix files with `\n`, old Mac files with `\r`;
a UTF-8 *byte order mark* (BOM) is an invisible `\ufeff` at the start that will sit in
your vocabulary as a "character" if you let it. Typesetting leaves curly quotes
(`“ ” ‘ ’`), em-dashes and the odd `™`. Control characters and giant blank gaps tell you
about scanning or conversion artefacts.

Why this matters for a language model: every distinct character is a row in your
embedding table and a possible output of the model. A character that occurs three times
in 3.9 million is capacity wasted on noise; two spellings of the same quote are two
things to learn. You decide *deliberately* what stays, and you can only decide what you
have counted.

A good habit: write the inspection as a small script that returns plain numbers (a
dict), so you can re-run it after cleaning and see what changed. This report is the
before picture; lesson 06 uses the same idea for the data card.

## The situation

Your workspace has `data/raw/` with the books (downloaded by lesson 01, or copied from
the offline cache if you skipped it). `report.py` has the interface and `show_report.py`
(finished) prints one summary per file.

## Your task

Implement `decode_bytes`, `char_inventory`, `data_report` and `report_dir` in `report.py`.
The docstring of `data_report` defines every key exactly. Verify runs your code on small
hand-made byte strings (BOM, CRLF, lone CR, invalid UTF-8, control characters, empty
input) and on the real files in `data/raw`, comparing against independent counts.

Then look at the real data:

    make py F=show_report.py

Write down for yourself: which books have a BOM? which use CRLF? which unusual
characters appear? Lesson 03 handles them.

## Useful commands

- `kdrill py` opens a Python shell with your workspace on the path (`import report`).
- `kdrill hint`, `kdrill reset` (your files go to `.backup/`), `kdrill solution`.

## On a real project

Profile every new source this way and keep the report next to the data. Tools like
`file`, `chardet`/`charset-normalizer` and `ftfy` help with encodings; for large corpora
you sample before you count.

## Read more

- Python Unicode HOWTO: https://docs.python.org/3/howto/unicode.html
- Byte order mark: https://en.wikipedia.org/wiki/Byte_order_mark
- The Absolute Minimum Every Software Developer Must Know About Unicode: https://www.joelonsoftware.com/2003/10/08/the-absolute-minimum-every-software-developer-absolutely-positively-must-know-about-unicode-and-character-sets-no-excuses/
