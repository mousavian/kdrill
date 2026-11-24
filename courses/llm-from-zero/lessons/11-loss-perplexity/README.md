# 11 - Loss and perplexity

## Concept

How good is a language model? The standard answer is **how surprised it is by real text**.
For each token the model assigns a probability to what actually came next. The
**negative log-likelihood** (NLL) is `-ln p`: 0 when the model was certain and right, large
when it gave the true token little probability, and infinite if it gave it none. The
average over many tokens is the **cross-entropy loss** that every model in this course is
trained to minimise. A model that knows nothing and spreads probability evenly over `V`
tokens scores `ln V`; any useful model must beat that.

**Perplexity** is `exp(loss)`: the number of equally likely choices the model is effectively
picking from at each step. A character model with perplexity 12 is as unsure as someone
choosing among 12 characters. It is easier to feel than nats, and the two carry the same
information (bits per token is nats divided by `ln 2`).

The crucial rule: **measure on data the model did not train on.** Training loss only tells
you how well the model fits what it has seen. An unsmoothed bigram model gives zero
probability to every pair absent from training, so on new text it can be infinitely bad while
its training loss looks wonderful: it has memorised. This is **overfitting**, the central
problem of the whole course. Whenever a setting controls how much the model memorises
(smoothing here, later weight decay, dropout, model size, training time) you choose it by
**validation loss**, never by training loss, and you touch the test set once, at the end.

Numerically, a probability of 0 must give `inf` cleanly (no NaN, no crash), and you should
get used to reading loss in nats, bits and perplexity interchangeably.

## The situation

`metrics.py` holds the interface on top of your `BigramModel`. `loss_report.py` prints the
train/validation table for several smoothing values on the real data.

## Your task

Implement `nll`, `perplexity`, `uniform_baseline`, `bits_per_token`, `evaluate`,
`smoothing_sweep` and `best_smoothing`. numpy only. Verify checks exact values on small
matrices, the infinite-loss case (it turns numpy warnings into errors), that the uniform model
scores `ln V`, a synthetic world where memorising wins on train but loses on validation (and
`best_smoothing` must not be fooled), and the real-text numbers.

Then `make py F=loss_report.py` and read the table: which smoothing wins on validation, and
what does the training column say?

## Useful commands

- `kdrill py`; `kdrill hint`; `kdrill solution`.

## On a real project

The same discipline applies to every metric: pick on validation, report on test. Perplexity
is only comparable between models that use the *same tokenizer* (a model with a bigger
vocabulary has a different per-token perplexity), which is why bits per character or per
byte are used to compare tokenizers.

## Read more

- Speech and Language Processing, ch. 3.3 (evaluating language models, perplexity): https://web.stanford.edu/~jurafsky/slp3/3.pdf
- Perplexity of fixed-length models (Hugging Face): https://huggingface.co/docs/transformers/perplexity
- Cross entropy: https://en.wikipedia.org/wiki/Cross-entropy
