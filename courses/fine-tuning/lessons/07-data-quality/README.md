# 07 - Data quality versus quantity

## Concept

"More data" is the first instinct and often the wrong one. A fine-tuning set is small enough that **every example
counts**, and a wrong example is not neutral: the model fits it. With a fixed number of steps, every wrong answer in
the file takes a share of the updates and pushes the weights toward a falsehood; when the same question appears with
the right answer elsewhere, the two fight and the model ends up unsure of both. Studies of instruction tuning keep
finding that a small, carefully checked set beats a larger, sloppy one (LIMA used a thousand examples).

The practical consequence is that **validating data is engineering work you do before training**, and wherever the
answer can be checked by a rule, you should check it by a rule. This task is built for that: each question is a
fact lookup (`What colour is the lamp?`), and a trusted table (`data/facts.json`) says what the answer is. A
validator then has three jobs:

1. **Parse the question** strictly. Anything that does not match one of the six templates is not a question of this task
   (and probably a data bug), so it is dropped, not guessed at.
2. **Compare the answer exactly** with the table, no stripping or case folding. A near-match is a different training
   target.
3. **Report** how noisy the file was. A noise rate of 35 percent is a finding about your data pipeline, not only a filter
   setting.

Two cautions. A filter has **precision and recall**: dropping a good example costs data; keeping a bad one costs
accuracy; check both on a case where you know the truth (the test does). And a rule-based validator only catches the errors
you thought of; for open-ended answers you would use a stronger check (a second model, a human sample, agreement between
sources) and the same measurement habit.

## The situation

`quality.py` has the six templates, a finished `load_facts`, and four functions to write. `run_quality.py` uses your
filter and your lesson 05 and 06 code to train twice for the same 250 steps: on `data/qa_noisy.jsonl` (300 examples, about
a third with a wrong answer) and on the validated subset (about 190 examples), and evaluates both on the held-out
questions.

## Your task

Implement `parse_question`, `is_consistent`, `split_clean` and `noise_rate`. Verify checks the parser on all 480
questions of the task and on near-misses, each kind of inconsistency (wrong answer, an answer of the wrong attribute, stray
space, case, unknown thing, unparseable question), the filter against a fresh noisy file with known labels (exactly the wrong
rows are dropped, order kept, input untouched), the bundled file, and an outcome run: the same 250 steps on the noisy rows
and on the validated rows, where the validated model must be at least 0.1 better in exact match. Then:

    make py F=run_quality.py     # about 20 s

Expect roughly 0.3 exact match on the noisy data and 0.45 on the validated subset (the numbers move by a few points with
the seed), with 37 percent fewer examples. Think about what you would do with the dropped rows: fix, re-label, or ask for more.

## Useful commands

- `make py F=run_quality.py`
- `kdrill py`: `from quality import *; parse_question("Where is the lamp kept?")`
- `kdrill hint`, `kdrill reset`

## On a real project

Quality work is mostly this loop: sample the data, find a failure pattern, write a check, measure the noise rate, fix or drop,
repeat. Teams keep the checks as code next to the dataset, version the data, and report the noise rate in the data card.
Model-based filters (a reward model, an LLM judge, perplexity under a reference model) extend the idea to answers a rule cannot check.

## Read more

- LIMA: Less Is More for Alignment: https://arxiv.org/abs/2305.11206
- Learning from Noisy Labels with Deep Neural Networks: A Survey: https://arxiv.org/abs/2007.08199
- Datasheets for Datasets: https://arxiv.org/abs/1803.09010
