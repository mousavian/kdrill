# 14 - Preference data: chosen and rejected

## Concept

Supervised fine-tuning shows the model *one* right answer. Often what you want is not a right answer but a **better**
one: the same facts, said more concisely, more politely, more safely. It is hard to write the perfect answer and easy to say
which of two is better. So **preference data** is made of triples: a prompt, a **chosen** completion and a **rejected**
completion. Training on them (lesson 15) pushes the model toward the chosen kind and away from the rejected kind.

Here the preference is visible: both answers are correct, the chosen one is **terse** (`grey`), the rejected one **chatty**
(`Why, grey, of course, and a most curious case it is`). A model tuned on a mix produces both; preference training should
steer it to terse without breaking the answers.

Preference data fails in its own ways, so validate it as you did the SFT data in lesson 05:

- **Empty or identical pairs** teach nothing (a loss of exactly zero gradient at best, noise at worst).
- **Swapped labels**: the chatty answer marked as chosen teaches the *opposite* of what you want, and a few percent of
  these quietly cancels the signal.
- **Pairs that are not comparable**: the rejected answer is about something else. The model could learn "different topic"
  instead of "worse style". The check here is that the rejected text contains the chosen answer.
- **Duplicates and leakage**: the same prompt twice inflates its weight; a prompt from the evaluation set makes the win rate
  meaningless.
- **Length bias**: here every rejected answer is longer, so a model could learn "shorter" instead of the style; real raters tend
  to favour *longer* answers. Look at the length gap before you trust a win rate.

The second half of the lesson is the building block of DPO: the **log-probability of a completion** given a prompt, summed
over its tokens, computed for a whole batch at once with padding, and differentiable. DPO compares this number for the chosen
and the rejected answer under two models (the one being trained and a frozen **reference** copy of the starting point).
Sum log-probabilities (multiplying probabilities underflows); only completion tokens count, as with the mask of lesson 06.

## The situation

`prefs.py` has seven functions. `data/pairs_raw.jsonl` has 252 messy rows (200 good pairs plus duplicates, identical pairs, empty
fields, swapped pairs, mismatched rejected answers and 8 pairs whose prompts are in the evaluation set).
`run_prefs.py` cleans it, fine-tunes the base on half-chatty answers (with your `train_sft`) and saves `models/sft_mixed.pt`,
the starting point for lesson 15.

## Your task

Implement `is_chatty`, `is_valid_pair`, `clean_pairs`, `encode_pair`, `completion_logprobs` and `length_gap`. Verify checks each validity
rule on its own, a freshly generated messy file (exactly the valid unique pairs without evaluation prompts survive), the details
(strip, first duplicate wins, no mutation), the encoding, `completion_logprobs` against a hand-computed sum for items of different lengths,
that it ignores padding and the other items of the batch and conditions on the prompt, that it is differentiable, and the length gap.
Then:

    make py F=run_prefs.py     # about 25 s

Read the last line: the SFT model is chatty in about 60 percent of its greedy answers, yet by raw summed log-probability it prefers the
*terse* answer on about two thirds of the held-out pairs. Both are true because they measure different things: greedy decoding takes the
most likely token at each step (the first token decides terse or chatty), the summed log-probability of a whole sequence falls with every
extra token. What does that say about comparing sequences of different length?

## Useful commands

- `make py F=run_prefs.py`; `head -2 ~/kdrill-work/fine-tuning/data/pairs_train.jsonl`
- `kdrill hint`, `kdrill reset`

## On a real project

Preference pairs come from human raters, from comparing two samples of the model (with a stronger model or a rule as judge), or from
edits (the corrected answer is chosen, the original rejected). Datasets such as UltraFeedback and HH-RLHF are used with exactly this
schema. Length normalisation and length-controlled win rates exist because length is the most common hidden variable.

## Read more

- Training language models to follow instructions with human feedback: https://arxiv.org/abs/2203.02155
- Direct Preference Optimization: https://arxiv.org/abs/2305.18290
- A Long Way to Go: Investigating Length Correlations in RLHF: https://arxiv.org/abs/2310.03716
