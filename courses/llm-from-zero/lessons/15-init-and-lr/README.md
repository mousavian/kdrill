# 15 - Training dynamics: initialisation and learning rate

## Concept

Two numbers you choose before training decide whether it works at all: how the weights
start, and how big each step is. Both can be diagnosed with a few measurements, so you do not
have to guess.

**Initialisation.** With `V` possible next tokens and no knowledge, the best prediction is
uniform and the loss is `ln V`. A freshly initialised model should start there. If the first
loss is far above `ln V` (the *hockey stick*: loss starts at 20 and falls to 3 in a hundred
steps) the output layer began with big random logits, the model is confidently wrong, and the
first steps are wasted shrinking weights. Fix: initialise the output layer small. The *hidden*
layer has a different job. `tanh` squashes its input into (-1, 1); if the weights are too large
the pre-activations are large, `tanh` **saturates** at +-1, its derivative `1 - h^2` goes to 0,
and those units barely learn; too small and everything is near zero. Scaling the weights by
`gain / sqrt(fan_in)` (Kaiming/He, with gain 5/3 for `tanh`) keeps the activations' spread
roughly constant from layer to layer.

**Learning rate.** Too small and nothing happens in your time budget; too large and the loss
explodes. The **range test** finds the window: raise the learning rate exponentially over a few
dozen steps while recording the loss. It falls, bottoms out, then blows up. A good rate is
somewhat below the bottom (here one tenth). A second diagnostic, the **update ratio**
`log10(lr * std(grad) / std(weight))`, says how big a step is relative to the weight; around -3
is healthy, far above means unstable, far below means too slow.

None of this needs theory to *use*: measure, look, adjust. Karpathy's "makemore" series calls
this "babysitting the training".

## The situation

`dynamics.py` builds on your `mlp_lm.py` from lesson 14. `dynamics_report.py` prints the
diagnostics for four initialisations and runs the range test on real data.

## Your task

Implement `kaiming_scale`, `make_params`, `hidden_stats`, `update_ratio`, `lr_range_test` and
`suggest_lr`. numpy only. Verify checks shapes and scales, the first loss with a small and a
large output layer, saturation statistics for tiny, huge and Kaiming-scaled `W1`, the update
ratio, the range test (copy of params, geometric lr, early stop on divergence, determinism) and
that the suggested rate trains clearly better than one 1000 times smaller or 100 times larger.

Run `make py F=dynamics_report.py` and compare the four rows.

## Useful commands

- `kdrill hint`; `kdrill solution`.

## On a real project

The same checks, with names: "loss at init", "activation histograms", "gradient-to-weight
ratio" in Weights & Biases or TensorBoard; the "LR range test" is from Leslie Smith's cyclical
learning-rate paper and the fast.ai library.

## Read more

- Delving Deep into Rectifiers (He et al., Kaiming init): https://arxiv.org/abs/1502.01852
- Cyclical Learning Rates for Training Neural Networks (LR range test): https://arxiv.org/abs/1506.01186
- A Recipe for Training Neural Networks (Karpathy): https://karpathy.github.io/2019/04/25/recipe/
