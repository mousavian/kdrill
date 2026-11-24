# Solution notes

- `copy.deepcopy(model.state_dict())` is essential: `state_dict()` returns references to the live tensors, which training keeps updating, so without the copy "the best weights" are just the current ones.
- Early stopping is a loop with three decisions (evaluate, remember if best, stop if patient no more) and one cleanup (restore). The test checks that stopping happens exactly `patience` evaluations after the best one.
- The decay group is chosen by `ndim`, a rule of thumb used by nanoGPT and most codebases. It keeps the embedding (a matrix) in the decay group and, because tied weights are one tensor, the output layer follows along.
- Run `overfit_demo.py` (about a minute): without regularisation the validation loss bottoms out near 2.37 around step 250 and then climbs to 2.8 while training loss keeps falling to 1.1 (a gap of 1.7); with dropout 0.2 and weight decay 0.1 it stays near 2.4 and the gap at the end is 0.6. Early stopping on the unregularised run would have returned the step-250 weights.
