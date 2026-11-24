# 08 - Byte-pair encoding from scratch

## Concept

Characters make sequences long; whole words make vocabularies huge and cannot handle a
word never seen. **Subword tokenization** sits in between, and **byte-pair encoding (BPE)**
is the classic way to learn it from data. Start with the 256 possible bytes (so *any* text
can be encoded, no unknown token ever), then repeat: count every pair of adjacent tokens,
merge the most frequent pair into a new token, record the merge. After a few hundred merges
common words and endings (`the`, ` and`, `ing`) are single tokens, while rare words fall
back to a few pieces or even single bytes.

Details that make it work:

- **Pre-tokenization.** Merges are learned inside chunks (a word with its leading space, a
  number, a run of punctuation), never across them. Without it BPE happily learns a token
  that glues the end of one word to the start of the next. It also makes training fast:
  count identical chunks once, weighted by frequency, instead of rescanning millions of
  characters for every merge.
- **Determinism.** When two pairs are equally frequent you need a fixed tie-break, or two
  runs give different tokenizers.
- **Encoding replays the merges in the order they were learned**: earliest merge first,
  repeatedly, until no learned pair is left. Cache per chunk; text repeats a lot.
- **Special tokens** such as `<|endoftext|>` are not text: they are cut out before
  pre-tokenization, never merged, and get their own ids after the merges.
- **Byte level means lossless**: decode the concatenated bytes once; a token boundary can
  fall inside a multi-byte character, so decoding uses a replacement character instead of
  raising.

This is the algorithm behind GPT-style tokenizers, in about 80 lines.

## The situation

`bpe.py` gives you `PRETOKEN`, `pretokenize` and `split_on_specials`, and the class skeleton.
The data is your training split (`data/train.txt`); the vocabulary must come from it only.

## Your task

Implement `merge_pair`, `count_pairs`, and `BPE` (`vocab_size`, `train`, `token_bytes`,
`_encode_chunk`, `encode`, `decode`, `to_dict`, `from_dict`). Verify checks: the classic
`aaabdaaabac` example (including the tie rule and stopping), your merges against a slow
independent trainer on real text, chunk boundaries and special tokens, round trips on
unicode, emoji and edge cases, `encode` against replaying the merges, compression and speed
(300 merges on 150 KB), serialisation, and that you did not import a tokenizer library.

## Useful commands

- In `kdrill py`: `from bpe import BPE; t = BPE.train(open("data/train.txt").read()[:200000], 300); t.encode("Mr. Sherlock Holmes")`
- To see what the merges are: `[t.token_bytes(256 + i) for i in range(30)]`

## On a real project

GPT-2 and friends use exactly this idea with a byte-level alphabet and a larger vocabulary
(50k); SentencePiece and WordPiece are cousins. Use a library (`tiktoken`, `tokenizers`) once
you understand this; training one on a new language or domain is the part you still do.

## Read more

- Neural Machine Translation of Rare Words with Subword Units (BPE for NLP): https://arxiv.org/abs/1508.07909
- Language Models are Unsupervised Multitask Learners (byte-level BPE in GPT-2): https://cdn.openai.com/better-language-models/language_models_are_unsupervised_multitask_learners.pdf
- Hugging Face LLM course, byte-pair encoding: https://huggingface.co/learn/llm-course/chapter6/5
