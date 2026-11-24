# 24 - Generation: temperature, top-k, top-p

## Concept

A trained model gives, at each position, a probability for every next token. **Generation** turns that
into text by repeating three steps: feed the text so far, get the distribution for the next token, choose
one, append it. The interesting part is *how you choose*, because the choice trades **quality** against
**diversity**.

- **Greedy** (always take the most likely token) is deterministic but dull and prone to loops: a model that
  thinks "the the the" is likeliest will write it forever.
- **Sampling** draws from the distribution, so text varies from run to run. Drawing from the *raw*
  distribution includes the long tail of silly tokens, each unlikely but together quite probable.
- **Temperature** `T` divides the logits before the softmax. `T < 1` sharpens (closer to greedy), `T > 1`
  flattens (more adventurous and more mistakes), `T = 0` is greedy by convention.
- **Top-k** keeps only the `k` most likely tokens and renormalises: a hard cut of the tail.
- **Top-p (nucleus)** keeps the smallest set of tokens whose probabilities add up to `p`: the cut adapts, so
  a confident step keeps one or two tokens and an uncertain one keeps many.
- A **repetition penalty** makes tokens that were already generated less attractive (positive logits shrink,
  negative ones grow more negative), a blunt tool against loops.

Details that bite: the model only accepts `block_size` tokens, so when the text grows you must **crop** to the
last `block_size` tokens before each forward pass; a generator must run in `eval()` mode with no gradients and
leave the model's mode as it found it; and a seeded `torch.Generator` makes a sample reproducible, which is
what you want in bug reports and in tests.

## The situation

`generate.py` has five functions to write: three filters, `sample_next` which chains them in a fixed order,
and `generate`. It works with any model following `logits, loss = model(idx)` with a `block_size` attribute,
so also with the GPT you built. `sample_demo.py` loads the checkpoint of `run_train.py` (lesson 22) if you
have one, and prints samples under six settings.

## Your task

Implement `top_k_filter`, `top_p_filter`, `apply_repetition_penalty`, `sample_next` and `generate`. Verify
checks each filter on small tensors (including ties, the crossing token of top-p and independent rows), that
sampled frequencies follow `softmax(logits / T)`, that tails are never sampled, that greedy and `top_k=1`
agree, that the penalty is applied first, that `generate` keeps the prompt, crops the context (a stub model
records the lengths it was fed), stops at an end-of-text token, restores the mode, and equals a step-by-step
argmax on a real GPT.

Then `make py F=sample_demo.py` and compare what the same model writes under each setting.

## Useful commands

- `kdrill py`; `kdrill hint`; `kdrill solution`.
- To use your tokenizer, `decode` the ids you get back.

## On a real project

Also: beam search, min-p, frequency and presence penalties, stop sequences, constrained decoding (grammars,
JSON), KV caching so that each step costs one position instead of the whole prefix. API parameters such as
`temperature` and `top_p` are exactly these.

## Read more

- The Curious Case of Neural Text Degeneration (nucleus sampling): https://arxiv.org/abs/1904.09751
- How to generate text (Hugging Face blog): https://huggingface.co/blog/how-to-generate
- CTRL (repetition penalty): https://arxiv.org/abs/1909.05858
