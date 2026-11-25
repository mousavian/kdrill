# 01 - Baseline: measure before you change anything

## Concept

Fine-tuning is a bet that a few more steps on a little new data make the model better at something. You cannot
tell whether the bet paid off without numbers from **before**. So the first thing in any fine-tuning project is not
a training loop; it is an **evaluation harness** and a **baseline**: the same measurements, run on the untouched
model, with code you will reuse unchanged for every later run.

This course measures three kinds of change on a tiny GPT (the one from `llm-from-zero`: 3 layers, 96 wide, about
0.4 million parameters, trained on Sherlock Holmes):

- **Style**: the model should get better at another voice. The measure is the loss on **held-out** text in that
  voice (here the last chapters of *Alice's Adventures in Wonderland*). Lower is better; the first token of a
  window has no context and is not scored.
- **Forgetting**: the model should not get worse at what it already did. The measure is the loss on held-out text of
  its *original* kind (Holmes). Fine-tuning that wins on style and loses here has a cost you must see.
- **Format**: the model should answer a question in a fixed shape, `Q: <question>\nA: <answer><end-of-text>`.
  Two numbers: **format accuracy** (it answered in the shape and stopped) and **exact match** (and the answer
  is right). Greedy decoding (always the most likely token) makes these numbers repeatable.

Two details that go wrong silently. A loss over many windows must weight every *token* equally, not every window
(the last window is short). And a model that is cropped to its context window must be fed at most `block_size`
tokens; a long prompt has to be cut from the left.

## The situation

`base.py` (finished; it also has `clone(model)` for independent copies) loads `base/checkpoint.pt`: your own `llm-from-zero` capstone model if it fits this course
(a context of at least 64 tokens), otherwise the reference base model that ships with the course. `base/SOURCE.txt`
says which one you got. `data/` holds the text and the question-answer files. `harness.py` has the interface.

## Your task

Implement `text_loss`, `complete`, `format_ok`, `exact_match`, `evaluate_qa`, `evaluate` and `write_results` in
`harness.py` (the docstrings list every rule). Verify checks them against independent computations and small
stand-in models: the windows and token weighting, greedy stopping at the end-of-text token, cropping, the counting
of format and exact match, and the baseline of the reference base model (it never answers in the format).

Then run the baseline on your own base:

    make py F=baseline.py        # about 15 s; writes results/baseline.json

With the reference base the style loss is about 3.46, the original loss 2.92, format and exact match 0. Keep this
file: later lessons compare against it.

## Useful commands

- `kdrill py` with no file opens a Python shell in the course container; `kdrill hint`, `kdrill reset`.
- `cat ~/kdrill-work/fine-tuning/base/SOURCE.txt`
- To use a capstone model you trained later: delete `base/checkpoint.pt` and run `kdrill start` again.

## On a real project

Real harnesses add many tasks (benchmarks, safety probes, latency), log every run with its configuration and a
data version, and store the numbers next to the checkpoint. The habit is the same: the baseline comes first, and
the evaluation code does not change between runs unless you re-run the baseline with it.

## Read more

- Holistic Evaluation of Language Models: https://arxiv.org/abs/2211.09110
- Perplexity of fixed-length models (sliding windows), Hugging Face docs: https://huggingface.co/docs/transformers/perplexity
- Language Models are Few-Shot Learners (held-out evaluation and contamination, section 4): https://arxiv.org/abs/2005.14165
