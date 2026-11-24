# 06 - Put it together and write the data card

## Concept

A pipeline you can only run by hand, in a notebook, in the right order, once, is not a
pipeline. Lessons 01 to 05 gave you the parts; now they become one function that takes a
folder of raw files and produces the dataset, **the same way every time**: same input and
same seed give byte-identical output, and the raw files are never modified. That is what
lets you change one rule next month and see exactly what changed.

The second half is documentation. A **data card** (after "Datasheets for Datasets" and
"Data Statements") answers the questions a future user, or you in six months, will ask: where
did this come from, under what licence, what was removed and how much, how is it split, what
does it contain, and what is it *bad* at? Writing it forces you to look at the numbers you
produced, which is when you notice that validation is one book, or that 8 percent of
paragraphs were dropped as too short.

Two details matter in practice. **Generate the card from the build's own statistics**,
not by hand, so it cannot go stale; the human part is the *limitations and biases* section,
which is the one thing a program cannot write. And **record checksums**: the card lists the
sha256 of every raw file, so the dataset is traceable to exact bytes.

Here the biases are real and worth naming: one author, one narrator, late-Victorian British
English with the attitudes of its time, nine books, a test set that is a single book. A
model trained on it will inherit all of that.

## The situation

`prepare.py` has the interface: `build_dataset` and `make_card`, both with a precise
contract in the docstring, and a `LIMITATIONS` list you must write yourself. It builds on
your own `clean.py`, `dedup.py` and `split.py`.

## Your task

Implement `build_dataset(raw_dir, out_dir, seed)` and `make_card(stats)`, and replace the
TODO entries in `LIMITATIONS` with three or more honest sentences about *this* data.
Verify builds a dataset from six synthetic books (Gutenberg wrappers, CRLF, a BOM, a planted
duplicate across books, a planted near-duplicate, planted junk) and checks: every book in
exactly one split, no paragraph in two splits, exact counts of what was removed, statistics
that match the written files, determinism, the card's sections and numbers, and that your
limitations are not placeholders. It also runs on real Gutenberg text.

Then build the real dataset: `make py F=prepare_run.py` writes `data/train.txt`,
`data/val.txt`, `data/test.txt` and `data/DATA_CARD.md`, which the modelling lessons use.

## Useful commands

- `cat ~/kdrill-work/llm-from-zero/data/DATA_CARD.md`
- `kdrill hint`, `kdrill reset`, `kdrill solution`.

## On a real project

Version the dataset (a hash of the files, a tag), store the card next to it, and rebuild in
CI. Model cards (lesson 27) point back to the data card.

## Read more

- Datasheets for Datasets: https://arxiv.org/abs/1803.09010
- Data Statements for NLP: https://aclanthology.org/Q18-1041/
- Model Cards for Model Reporting: https://arxiv.org/abs/1810.03993
