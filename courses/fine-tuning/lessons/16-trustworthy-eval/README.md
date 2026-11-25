# 16 - Evaluation you can trust

## Concept

A fine-tuning result is a number, and a number is only worth something if you know what could make it wrong. Two things make
fine-tuning numbers wrong more often than anything else.

**Contamination.** If the evaluation text (or something very close to it) was in the training data, the model has seen the answers
and the score measures memory. It happens by accident all the time: the same paragraph in two files, a benchmark scraped into a web
corpus, a prompt template reused in both sets. The standard cheap check is **n-gram overlap**: split texts into words, list every run
of `n` consecutive words (an *n-gram*; 8 to 13 are typical for prose) and ask how many of the evaluation's n-grams occur in the training
set. One shared 8-gram is a flag worth reading; a high overlap *rate* means the evaluation is compromised. For short items the whole text
is the unit, so here a text shorter than `n` words counts as one gram. The remedy is to **decontaminate**: remove the offending
examples from the training side, and say so. Contamination is not design: in this course's question set every *fact* is in training on
purpose (nobody could answer otherwise), but no evaluation *question* is.

**Noise.** Train the same configuration twice with two seeds and you will get two different numbers: the adapter starts differently,
the batches come in another order. A difference between two settings smaller than that spread is no difference. So run several seeds, report
mean and **standard deviation**, and compare settings with a **confidence interval** on the *paired* differences (seed 0 of A against seed
0 of B, and so on; pairing removes the variation shared by both, so small consistent gains are visible). With few seeds use the
**t distribution**, not the normal one: for 4 seeds the 95 percent multiplier is 3.18, not 1.96. The test set has its own noise: an accuracy
measured on `n` items has a standard error of `sqrt(p (1 - p) / n)`; 55 percent on 100 questions is 55 plus or minus 10.

For the capstone: decide the metric before you look, run at least 3 seeds for any claim of improvement, report the interval, and
when it contains zero write "no measurable difference".

## The situation

`trust.py` is pure Python: no numpy, no scipy (the t table is in the file). `run_trust.py` runs your checks on this course's own data
(paragraph overlap between the books and the question files) and then compares LoRA rank 2 and rank 8 over four seeds using your
`lora_run` from lesson 09, printing the interval.

## Your task

Implement `words`, `ngrams`, `build_index`, `contaminated`, `overlap_rate`, `decontaminate`, `mean_std`, `ci95`, `paired_summary` and
`binomial_se`. Verify checks each on small hand-made cases (planted copies, case and punctuation, short texts, repeated n-grams, the
sample deviation, table entries and the fallback for degrees of freedom not in the table, consistent small gains versus large noisy
ones), the real course data (the held-out questions are clean; planted copies are found; the books' overlap is small), and a
real three-seed comparison of rank 8 against rank 2. Then:

    make py F=run_trust.py      # about 45 s

## Useful commands

- `make py F=run_trust.py`
- `kdrill hint`, `kdrill reset`

## On a real project

Contamination checks run at web scale with hashing and suffix arrays; benchmark authors publish canary strings; reports say how a model's
evaluation sets were checked. For stochastic metrics people also report paired bootstrap intervals and use more seeds; with only a handful
of runs the t interval you wrote is the honest minimum.

## Read more

- Language Models are Few-Shot Learners (section 4, measuring and preventing contamination): https://arxiv.org/abs/2005.14165
- Deep Reinforcement Learning that Matters (seeds and significance): https://arxiv.org/abs/1709.06560
- Documenting Large Webtext Corpora (contamination and data documentation): https://arxiv.org/abs/2104.08758
