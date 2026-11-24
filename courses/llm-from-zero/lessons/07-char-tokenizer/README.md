# 07 - A character tokenizer

## Concept

A neural network works on numbers, not text. A **tokenizer** is the bridge: it cuts text
into pieces (tokens), gives each piece an integer id, and can turn ids back into text. The
simplest choice is one token per character. The vocabulary is tiny (about 80 symbols for
English prose), nothing is ever "out of vocabulary" for text over the same alphabet, and the
code is a dozen lines. The price is long sequences: a 70-character line is 70 tokens, and a
model with a fixed context window sees little text per window. Lesson 08 trades that off
with byte-pair encoding.

Three details decide whether a tokenizer is safe to build a model on.

- **Build the vocabulary from the training split only.** Looking at validation text when
  choosing the vocabulary is a quiet form of leakage (lesson 05).
- **Be explicit about what you do not know.** A character that never occurred in training
  must map to a reserved `<unk>` id, never raise, never collide with a real character. The
  decode direction is then lossy for unknowns, and you should *measure* how lossy (the
  unknown rate on validation).
- **Be deterministic and serialisable.** The same text must always give the same ids, in the
  same order after a restart. Sorting the characters makes ids reproducible, and saving the
  vocabulary next to a checkpoint means a model can be used a year later.

Reserved ids (here `<pad>` = 0 for padding batches, `<unk>` = 1) come first so that real
tokens never move when you add more specials later.

## The situation

`tok_char.py` defines the class and its docstrings. Your cleaned splits live in
`data/train.txt`, `data/val.txt`, `data/test.txt` (from lesson 06, or a bundled copy if you
skipped it).

## Your task

Implement `CharTokenizer` (`vocab_size`, `fit`, `encode`, `decode`, `to_dict`, `from_dict`,
`save`, `load`) and `unk_rate`. Verify checks the id layout, round trips on random text,
unknown characters, padding and bad ids, refitting, serialisation, and the real splits (few
unknown characters).

## Useful commands

- `kdrill py`: `from tok_char import CharTokenizer; t = CharTokenizer().fit(open("data/train.txt").read()); t.vocab_size`
- `kdrill hint`, `kdrill solution`, `kdrill reset`.

## On a real project

You almost never train a character model on real data: tokens are subwords (next lesson).
But the `<pad>`, `<unk>`, vocabulary file and unknown-rate habits carry over unchanged.

## Read more

- Python `json`: https://docs.python.org/3/library/json.html
- Hugging Face, Summary of the tokenizers: https://huggingface.co/docs/transformers/tokenizer_summary
- The Unreasonable Effectiveness of Recurrent Neural Networks (character models): https://karpathy.github.io/2015/05/21/rnn-effectiveness/
