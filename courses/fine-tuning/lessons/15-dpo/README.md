# 15 - DPO from scratch

## Concept

Reinforcement learning from human feedback (RLHF) trains a separate reward model on preferences and then optimises the language
model against it with an RL algorithm: three stages, many moving parts. **Direct Preference Optimization** (DPO) shows that the
same objective can be optimised with one supervised-looking loss on the preference pairs themselves, no reward model and no sampling.

The ingredients are the numbers from lesson 14: the summed log-probability of the chosen completion `pc` and of the rejected one `pr`
under the **policy** (the model you train), and the same two numbers `rc`, `rr` under a frozen copy of the starting model, the
**reference**. DPO's loss is

    loss = - log sigmoid( beta * ((pc - rc) - (pr - rr)) )

Read the inside: `pc - rc` is how much *more likely* the policy made the chosen answer than the reference did; `pr - rr` the same for
the rejected one. The loss falls when the policy raises the chosen answer and lowers the rejected one **relative to where it started**.
At the start policy and reference are equal, the margin is 0 and the loss is `ln 2 = 0.693`; that is the first thing to check in any DPO run.
`beta * (pc - rc)` is called the **implicit reward**.

Why the reference matters: raw log-probabilities favour short answers (lesson 14), so without it the model would just learn "be
short". The reference ties the policy to where it started: the margin measures *change*, and beta scales it: a large beta saturates the
sigmoid early, so training stops pushing once a modest change in log-probability is reached; a small beta keeps pushing.

Practical rules this lesson makes you do:

- **Compute the reference log-probs once**, before training, and never update the reference model.
- **Use `logsigmoid`**, never `log(sigmoid(x))`: for a margin of -1000 the second form is `log(0) = -inf`.
- **Constants carry no gradient**: only `pc` and `pr` flow into the policy.
- **Measure the thing you want**, not only the loss: the **win rate** on held-out pairs (how often the policy moved toward the chosen
  answer more than toward the rejected one) and the share of chatty answers it generates.

## The situation

`dpo.py` imports `completion_logprobs` and `encode_pair` from your `prefs.py`. The start is `models/sft_mixed.pt`: the model from lesson 14's
`run_prefs.py` (or, if you skipped it, the reference SFT model that ships with the course, copied there by setup). `run_dpo.py` trains it with
three values of beta and prints chatty share, win rate and whether the answers still contain the right word.

## Your task

Implement `implicit_rewards`, `dpo_loss`, `reference_logprobs`, `dpo_train` and `win_rate`. Verify checks the loss on hand-computed numbers
(`ln 2` at zero margin, `softplus(-0.5)` for a margin of 5 at beta 0.1, larger beta rewards a positive margin more), numerical stability at
-1000, the gradient signs and that nothing flows to the reference, that the reference log-probs equal `completion_logprobs` and the model
is left alone, that the first training loss is `ln 2`, the reference never changes, the policy does, the run is reproducible and `win_rate` is
0 for identical models, and an outcome run: 60 steps take the chatty share from at least 40 percent to at most 25 percent, with a win rate of at
least 0.9 on held-out pairs and the right word still in the answers. `trl` is forbidden. Then:

    make py F=run_dpo.py      # about 25 s

Reference numbers: the SFT model is chatty on about 62 percent of the 40 prompts; after 60 steps the chatty share is about 12 percent at
beta 0.05 and 0.1 and about 28 percent at beta 0.5, the win rate on held-out pairs is 1.00 in all three, and the loss ends at 0.29, 0.18
and 0.07. Look at the beta rows: the largest beta has the lowest loss and the weakest effect on the answers. Why? (Hint: where does the
sigmoid saturate?)

## Useful commands

- `make py F=run_dpo.py`; `cat results/dpo.json`
- `kdrill hint`, `kdrill reset`

## On a real project

DPO needs two forward passes per sequence (policy and reference; the reference ones can be precomputed or run in `no_grad`) and learning rates around
`5e-7` for large models, much lower than SFT. Variants fix its known problems: IPO and cDPO against overfitting to the preferences, SimPO and
length-normalised variants against length bias, KTO when you only have thumbs up and down. Run an SFT stage first: DPO assumes the policy can already
produce both kinds of answer.

## Read more

- Direct Preference Optimization: Your Language Model is Secretly a Reward Model: https://arxiv.org/abs/2305.18290
- Training language models to follow instructions with human feedback: https://arxiv.org/abs/2203.02155
- Hugging Face TRL, DPO trainer: https://huggingface.co/docs/trl/dpo_trainer
