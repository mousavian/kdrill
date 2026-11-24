# 03 - Clean it

## Concept

Raw text is a product of its container. A Project Gutenberg file wraps the book in a
licence header and footer, adds a table of contents, scatters `[Illustration]` tags,
sets quotes in typographic style, and hard-wraps every paragraph at ~70 columns. None of
that is the language you want the model to imitate, and some of it actively hurts: a
model trained on the licence boilerplate will happily generate licence boilerplate, and a
model that sees every paragraph chopped into 70-character lines spends capacity learning
where the line breaks fall.

Cleaning is a sequence of small, **testable** rules, each doing one job:

1. Make newlines uniform and remove invisible characters (BOMs, zero-width spaces).
2. Cut the boilerplate that is not part of the work (here: header, footer).
3. Remove structure that is not prose (contents, illustration tags).
4. Normalise Unicode: compose accents (NFC), map curly quotes, dashes and exotic spaces
   to a small set, drop control characters, collapse whitespace.
5. Undo hard wrapping, so a paragraph is one line of text.

Two principles matter more than any single rule. **Order matters**: the contents rule needs
the blank-line structure that whitespace collapsing destroys, so it runs first. And a
cleaner should be **idempotent**: cleaning clean text must change nothing, otherwise you
cannot re-run a pipeline safely. Always test on *tricky samples*, not on the one book you
looked at: a marker spelled in lower case, a title that wraps over two lines, the words
"Project Gutenberg" inside a story that must stay.

You also decide what *not* to do. Here we keep accented letters and the few real symbols; a
more aggressive cleaner (ASCII-only) would shrink the vocabulary but erase `café`.

## The situation

`clean.py` has the interface, the `CHAR_MAP` of replacements (use it as given) and
docstrings that define every rule. `try_clean.py` shows the result on a real book.

## Your task

Implement `fix_newlines`, `strip_gutenberg`, `drop_contents`, `drop_illustrations`,
`normalize`, `unwrap_paragraphs` and `clean_book` (the pipeline, in the stated order).
Verify throws samples at each function that you have not seen: header and footer
variants, a contents block with and without a clear end, illustration tags inside
sentences, mixed whitespace, random messy input (idempotence), and finally the real
books in `data/raw`. Plain Python: the `re` and `unicodedata` modules are all you need.

## Useful commands

- `make py F=try_clean.py` shows the cleaned start of a real book.
- In `kdrill py`: `import clean; clean.normalize("“Hi”")`.

## On a real project

Large pipelines add language identification, quality classifiers and PII scrubbing, but
the core is the same: many small, tested filters with counts of what each one removed
(lesson 04 does that for duplicates).

## Read more

- Unicode normalization forms: https://unicode.org/reports/tr15/
- Python `re` module: https://docs.python.org/3/library/re.html
- Python `unicodedata`: https://docs.python.org/3/library/unicodedata.html
- Gutenberg header/footer conventions: https://www.gutenberg.org/help/mirroring.html
