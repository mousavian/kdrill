# 05 - Instruction data: template, cleaning, splitting

## Concept

**Supervised fine-tuning (SFT)** teaches a model a behaviour by showing it examples of that behaviour: a prompt and
the completion you want. The model is trained with the same next-token loss as before; what changes is that the text
is no longer a book but a thousand small, regular documents. That makes the *shape* of each document matter more than
anything else.

Four things to get right, each a classic source of silent failure:

- **A fixed template.** Every example is `Q: <question>\nA: <answer>` and then an **end-of-text** token. The model
  learns the template as a pattern; at test time the prompt `Q: ...\nA:` is the cue and the model should continue in
  the template. Training and test prompts must be built by the *same* function.
- **The stop token.** Without the end-of-text token at the end of every completion the model never learns to stop; it
  keeps going into a made-up next question. Lesson 01's format accuracy would stay at zero.
- **Cleaning and deduplication.** Whitespace noise, empty fields, absurdly long rows, rows containing the stop marker
  or a newline in the answer (they break the template), and duplicates all waste steps or teach the wrong thing.
  Duplicates also inflate every metric: the same question must not be in training and evaluation.
- **Split after deduplicating, by question.** If the same question can land on both sides, the evaluation measures
  memory, not learning. Here every fact (a colour or a room) is asked in three phrasings; the held-out set uses
  phrasings the model has not seen, so a good score means it learned the fact *and* the way to ask.

One technical detail: the prompt and the completion are tokenized **separately** and joined. That is only safe when the
tokenizer would have split the text at that boundary anyway (here at the colon of `A:`, where the next token starts with
a space). Test it, do not assume it.

## The situation

`data/qa_raw.jsonl` is a messy file of 314 rows (about 260 distinct valid questions; the rest are duplicates, spacing
variants, empty fields, rows that are far too long, rows with the marker or a newline in the answer). `sft_data.py` has the
interface; `prepare_sft.py` runs your functions on the file.

## Your task

Implement `clean_text`, `format_example`, `clean_examples`, `split_examples`, `encode_example`, `encode_all` and
`dataset_stats`. Verify generates a **new** messy file (a seed you have not seen) and checks that the cleaning keeps
exactly the valid unique questions once, each rule on its own, the split (disjoint, complete, reproducible, original order,
duplicates and bad fractions rejected), that prompt + completion tokens equal the tokens of the whole string and end with the
end-of-text id, and the length limit. Then:

    make py F=prepare_sft.py    # a few seconds; writes data/sft_train.jsonl and data/sft_eval.jsonl

Look at the printed `answer_share`: only about a fifth of the tokens of a training example are the answer. Lesson 06
is about what to do with the rest.

## Useful commands

- `kdrill py`, then `from sft_data import *` and try `format_example("a", "b")`.
- `head -3 ~/kdrill-work/fine-tuning/data/qa_raw.jsonl`
- `kdrill hint`, `kdrill reset`

## On a real project

Real instruction sets are cleaned with the same steps plus near-duplicate detection (hashing, MinHash), language and
length filters, removal of personal data and a check against the evaluation sets (lesson 16). Chat models use a template
with special role tokens (`<|user|>`, `<|assistant|>`) instead of `Q:`/`A:`; it must be reproduced exactly at inference,
and a template mismatch between training and serving is a very common reason for a model that "got worse".

## Read more

- Finetuned Language Models Are Zero-Shot Learners (FLAN, instruction tuning): https://arxiv.org/abs/2109.01652
- Training language models to follow instructions with human feedback (InstructGPT): https://arxiv.org/abs/2203.02155
- Deduplicating Training Data Makes Language Models Better: https://arxiv.org/abs/2107.06499
- Hugging Face, chat templates: https://huggingface.co/docs/transformers/chat_templating
