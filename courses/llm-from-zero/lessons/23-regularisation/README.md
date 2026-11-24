# 23 - Overfitting and regularisation

## Concept

A model with enough parameters can *memorise* its training data: training loss keeps falling while
validation loss bottoms out and then **rises**. The distance between the two curves is the
**generalisation gap**, and everything in this lesson exists to keep it small. (Lesson 11 showed the
same thing with an unsmoothed bigram; here it happens to a transformer.) With small data, a small model
and a long run, you will see it within minutes.

Three tools, each answering "how do I stop the model from fitting noise?":

**Weight decay** pulls every weight a little toward zero at each step, which favours smaller weights and
simpler functions. AdamW applies it *decoupled* from the gradient: `w -= lr * wd * w`. It makes sense for
**weight matrices and embeddings**, not for **biases and LayerNorm scales**, which are few, do not
overfit and should be free to take any value. So the optimiser gets two parameter groups, distinguished
by `ndim`. Watch out for **tied** weights: the embedding appears under two names but is one tensor and
must be in exactly one group.

**Dropout** randomly zeroes a fraction of activations during training (here inside attention weights, the
projections and the feed-forward output), so no unit can rely on a particular partner. Because the mask is
random, the network is effectively an ensemble of many thinned networks. It is active only in `train()`
mode; `eval()` switches it off and (with the standard scaling) needs no correction.

**Early stopping** is the cheapest of all: evaluate on validation data every so often, remember the weights
of the best evaluation, and stop when it has not improved for `patience` evaluations. Then **restore the
best weights**, not the last: the last ones are the most overfit. This is also where your discipline from
lesson 05 pays off: the validation set is now being used to *choose* (the stopping step), so the final
number you report must come from the untouched test set (lesson 25).

More data and a smaller model are the strongest regularisers; the others fine-tune.

## The situation

`regularize.py` builds on your `loop.py` helpers and the dropout in your GPT. `overfit_demo.py` trains a
model that is too big for 6,000 characters twice (without and with dropout and weight decay) and prints
train, validation and the gap every 100 steps.

## Your task

Implement `configure_optimizer`, `EarlyStopping` and `train_with_early_stopping`. Verify checks the group
split (and that tied weights appear once and frozen ones not at all), the actual effect of weight decay on
a matrix versus a bias, the early-stopping logic including `min_delta`, a run on random tokens that must
stop early and restore the best weights (checked by re-evaluating), that validation tokens never train the
model, dropout's train/eval behaviour, and a short real run.

Then `make py F=overfit_demo.py` (about a minute) and compare the gap in the two runs.

## Useful commands

- `kdrill py`; `kdrill hint`; `kdrill solution`.

## On a real project

Large language models are rarely trained for more than one pass over a huge dataset, which is itself the
regulariser (there is no repeated data to memorise); dropout is often set to 0. Fine-tuning small datasets
(`fine-tuning` course) is where early stopping and weight decay come back.

## Read more

- Dropout: A Simple Way to Prevent Neural Networks from Overfitting: https://jmlr.org/papers/v15/srivastava14a.html
- Decoupled Weight Decay Regularization: https://arxiv.org/abs/1711.05101
- Early stopping, but when? (Prechelt): https://page.mi.fu-berlin.de/prechelt/Biblio/stop_tricks1997.pdf
