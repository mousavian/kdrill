# 09 - Vocabulary size trade-offs

## Concept

How many merges should BPE learn? There is no right answer, only a trade-off with numbers
on both sides.

**More merges, shorter sequences.** Each merge removes a token wherever the pair occurs, so
tokens per word falls and bytes per token rises. Short sequences are good: a model with a
fixed context window of 256 tokens sees more text, attention (which grows with the square of
the length) costs less, and generation needs fewer steps. The gains shrink quickly: the
first merges (`t`+`h`) save a lot, the 1500th (a rare name) saves almost nothing.

**More merges, more parameters and sparser training.** Every token is a row in the
embedding table (and in the output layer, if untied). A token that appears only a handful of
times in training gets a handful of gradient updates, so its vector stays close to random,
and when it does appear in validation text the model has little to say about it. The share
of *rarely used* merged tokens is a good indicator of vocabulary you cannot afford on this
amount of data. Tiny datasets want small vocabularies; web-scale models use 30 to 250 thousand.

So the method is: train once with the largest size you will consider, then slice, because the
first k merges of a deterministic BPE *are* the k-merge tokenizer. Measure each size on
**validation** text (tokens per word, bytes per token, rare fraction) and on the cost side
(embedding parameters). Then choose, and write down why in numbers, which is what a model
card or a design review needs.

## The situation

`vocab_study.py` has the interface and uses your `BPE`. `vocab_report.py` runs the study on
the real data. `vocab_choice.json` is where your decision goes.

## Your task

1. Implement `tokens_per_word`, `bytes_per_token`, `rare_fraction`, `embedding_params`,
   `study` (train once, slice the merges) and `choose_size`.
2. Run `make py F=vocab_report.py` (about 40 s). Look at the table.
3. Edit `vocab_choice.json`: your `vocab_size` (an integer) and a `reason` of at least 80
   characters that cites at least three numbers from the table.

Verify checks the metrics on tiny cases, that `study` equals separately trained tokenizers
and is fast, the trends, `choose_size`, and that your json is filled in with numbers. (It
does not check *which* size you picked: 300 to 1500 are all defensible for 4 million
characters; that is the point.)

## Useful commands

- `make py F=vocab_report.py`, then `cat vocab_choice.json`.
- `kdrill hint`, `kdrill solution`.

## On a real project

Production tokenizers are also tuned for multilingual coverage, code, and numbers (splitting
digits one by one helps arithmetic). Changing the tokenizer later means retraining the
model, so this decision is made early.

## Read more

- Tokenization in LLMs (Hugging Face LLM course): https://huggingface.co/learn/llm-course/chapter6/1
- Scaling Laws with Vocabulary: https://arxiv.org/abs/2407.13623
- How Good is Your Tokenizer? (Rust et al.): https://aclanthology.org/2021.acl-long.243/
