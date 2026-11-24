# 26 - Evaluation beyond a single loss

## Concept

You have been watching validation loss all along. It is the right number to *train* against, but it
is not the whole story about a model, and it is not the number to *report*.

**Report on the test set, once.** Validation data has been used to choose things (learning rate, stopping
step, vocabulary size). Each choice leaks a little. The test split was kept untouched for exactly one
purpose: the final, honest estimate. Evaluate on it when the model is finished, write the number down, and do
not tune against it.

**Score every token exactly once, with good context.** To measure perplexity on a long text with a model that
sees `block_size` tokens, cut it into windows. Non-overlapping windows are simple but pessimistic: the first
tokens of each window are predicted with almost no context. A **sliding window** with a stride smaller than the
block scores only the *new* tokens of each window, so every token is predicted with up to a full window of
context, and each is counted once. The more overlap, the more compute and the better (lower) the estimate.

**Make numbers comparable.** Perplexity per token depends on the tokenizer: a model with bigger tokens has a
higher per-token loss for the same text. **Bits per character** (total nats divided by characters times
`ln 2`) is comparable across tokenizers.

**Probe for specific abilities.** A single average hides what the model can and cannot do. A probe is a
tiny, targeted test: given a prompt, is the right continuation more likely than the wrong ones? ("Mr. Sherlock
" followed by "Holmes" beats "Hqxzy".) Dozens of such probes tell you more than a fourth decimal of loss.

**Check for contamination.** If test text also occurs in training data, the score measures memory, not skill.
An n-gram overlap check catches the obvious cases; it is the reason published benchmarks come with
contamination analyses.

**Ask humans, blind.** For generated text, nothing beats a person reading two samples. To keep it fair,
hide which model wrote which, randomise the order per prompt, and unblind afterwards from a key file.

## The situation

`evaluation.py` has six functions around a model that follows `logits, loss = model(idx)`.
`eval_report.py` (about a minute) evaluates the checkpoint from `run_train.py` on the test split: test loss, perplexity, bits per
character, contamination and two probes.

## Your task

Implement `perplexity_on_text`, `bits_per_char`, `continuation_logprob`, `run_probes`, `contamination` and
`write_side_by_side`. Verify uses a model that depends only on the previous token, so the correct loss has a
closed form for *any* block size and stride (it checks eight combinations, plus the token count and independence
from `batch_size`), a trained GPT where more context must not hurt, exact log-probability sums, probes with known
outcomes, a contamination example, and the blinded sheet with its key.

## Useful commands

- `make py F=eval_report.py`
- `kdrill py`; `kdrill hint`; `kdrill solution`.

## On a real project

Use established harnesses (EleutherAI's lm-evaluation-harness) for public benchmarks, keep a private held-out
set that never leaves your team, and track the metric that matches the product. Be honest about the limits of every
benchmark: they saturate, get leaked, reward what is easy to score, and rarely measure what you will use the model for.

## Read more

- Perplexity of fixed-length models (Hugging Face, sliding window): https://huggingface.co/docs/transformers/perplexity
- Language Models are Few-Shot Learners, section 4 (contamination analysis): https://arxiv.org/abs/2005.14165
- lm-evaluation-harness: https://github.com/EleutherAI/lm-evaluation-harness
