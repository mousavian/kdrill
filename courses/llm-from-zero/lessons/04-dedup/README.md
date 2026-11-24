# 04 - Filter and deduplicate

## Concept

Duplicates quietly damage a language model in two ways. A paragraph that appears ten
times is learned ten times as hard, so the model memorises it and repeats it. Worse,
duplicates that straddle your train/validation split make validation loss look better than
it is (lesson 05). Real corpora are full of them: the same story in two collections, the
same boilerplate on every page, a poem quoted in two chapters.

There are two kinds. **Exact duplicates** are found by hashing a *normalised* version of
the text (lower case, no punctuation or spacing) and remembering the hashes you have seen:
cheap and precise. **Near-duplicates** (a reprint with one edited word) need a similarity
measure. Break each paragraph into overlapping word *shingles* (k consecutive words) and
compare the sets with **Jaccard similarity**, `|A and B| / |A or B|`. Comparing every pair is
quadratic, which is hopeless at scale, so you build an **inverted index** from shingle to
paragraphs and only compare paragraphs that share at least one shingle. (Big pipelines
use MinHash and locality-sensitive hashing to do the same thing with fixed-size sketches.)

Filtering is the other half: paragraphs that are too short or mostly symbols (rules,
page numbers, tables) are noise. Every threshold is a judgement call: a minimum length of
40 characters would delete most of the dialogue in a detective story, so the defaults here
are modest and the thresholds are parameters.

The most important habit: **count what each rule removes and why**. A filter that silently
deletes 30 percent of your data is a bug you will not find otherwise. `filter_and_dedup`
returns those numbers and the data card (lesson 06) reports them.

## The situation

`dedup.py` defines the interface, with the exact semantics in each docstring.
`report_filters.py` runs the step on the real corpus and prints the percentages.

## Your task

Implement `paragraphs`, `norm_key`, `exact_dedup`, `shingles`, `jaccard`, `near_dedup`,
`junk_reason` and `filter_and_dedup`. Verify checks them on small hand-made cases with
known answers (including a chain of paragraphs, and "the earlier one wins"), on a planted
corpus with exact expected counts, and with a scaling test: 4000 paragraphs must finish in
a few seconds, which only an inverted index achieves. Plain Python only.

Then look at the real numbers: `make py F=report_filters.py`.

## Useful commands

- `kdrill hint`, `kdrill solution`, `kdrill reset`.
- Time a call in `kdrill py`: `import time; t=time.time(); ...; time.time()-t`.

## On a real project

Deduplicate at several levels (document, paragraph, n-gram), and across the train/test
boundary especially. Search engines and web-scale datasets use MinHash + LSH
(for example the datasketch library).

## Read more

- Mining of Massive Datasets, ch. 3 (similar items, shingling, MinHash): http://www.mmds.org/
- Deduplicating Training Data Makes Language Models Better: https://arxiv.org/abs/2107.06499
- Jaccard index: https://en.wikipedia.org/wiki/Jaccard_index
