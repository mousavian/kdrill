# 25 - A small scaling experiment

## Concept

How much better does a model get if you make it bigger, train it longer, or give it more data? Kaplan et
al. (2020) and Hoffmann et al. ("Chinchilla", 2022) answered by training hundreds of models and finding that
**loss follows smooth power laws**: `L ~ a * X^b` with a small negative exponent `b`, in model parameters `N`,
in training tokens `D` and in compute `C`. Plotted on log-log axes the curves are straight lines. This
predictability is why labs can forecast a 100x larger run from small ones.

The practical question is about a **fixed budget**. Training compute is roughly `6 * N * D` floating-point
operations (about 6 per parameter per token for forward plus backward). Spend a fixed budget `C` and you
choose between a *bigger* model on *fewer* tokens or a *smaller* one on *more*. Both extremes lose: too small
and the model is capacity-limited, too big and it has seen too few tokens to use its capacity. In between is a
**compute-optimal** size, and Chinchilla's finding was that parameters and tokens should grow together (very
roughly 20 tokens per parameter), unlike the earlier practice of ever bigger models on a fixed amount of data.

Your experiment is a miniature of that: four model sizes, the same compute, and the validation loss of each.
Treat the result with the humility it deserves. Here the models are tiny, the data is 4 MB of one author, the
learning rate is not tuned per size and each point is a single seed, so the *shape* (a U or a plateau) is
informative and any exponent you fit is not a law. Real scaling studies tune the learning rate per size, use
several seeds and a much wider range. The tools, though, are exactly the ones you write now: a FLOP counter, a
budget-to-steps converter, a log-log power-law fit, and plots.

## The situation

`scaling.py` has the helpers; `run_one` trains one configuration on a budget using your `GPT` and `train`.
`scaling_run.py` runs four sizes at two budgets and saves `out/scaling.png`.

## Your task

Implement `train_flops`, `steps_for_budget`, `fit_power_law`, `predict_power_law`, `plot_curves` and
`run_one`. Verify checks the formulae and rounding, the power-law fit on exact and noisy data (and its error
cases), that the plot is a valid PNG, and that `run_one` really spends the budget (bigger model, fewer steps)
and is reproducible for a seed. matplotlib is used only to save the figure.

Then the experiment: `make py F=scaling_run.py` (about 2.5 minutes on 2 CPUs; two budgets, four sizes).
Open `out/scaling.png` (in your workspace folder) and write down what you see: which size wins at each budget?
does the gap between the sizes shrink when the budget grows? what would you expect at ten times the budget?

## Useful commands

- `ls ~/kdrill-work/llm-from-zero/out/`
- `kdrill py`; `kdrill hint`; `kdrill solution`.

## On a real project

Use `torch.utils.flop_counter` or measured throughput instead of `6ND` when attention cost matters (long
context), tune the learning rate for every size, and fit `L(N, D)` jointly with an irreducible-loss term.

## Read more

- Scaling Laws for Neural Language Models (Kaplan et al.): https://arxiv.org/abs/2001.08361
- Training Compute-Optimal Large Language Models (Chinchilla): https://arxiv.org/abs/2203.15556
- Transformer FLOPs (Adam Casson): https://www.adamcasson.com/posts/transformer-flops
