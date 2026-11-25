# Solution notes

- **Damage is relative**: a 0.3 rise of loss means more on a model at 2.9 than at 5.0, and the percentage lets you compare
  models and tasks. Always compute it against the base loss on the *same* held-out old text.
- **Replay costs new-data steps.** With `replay=0.5` half of every batch is old text, so the model sees half as much
  new text for the same number of steps; that is the price of staying close to the base.
- **The replay share is a knob, not a constant.** In the reference experiment 0.25 already removes most of the damage at
  both learning rates (7.0 percent at lr 1e-3 falls to 1.2 percent); 0.5 removes all of it. Pick the smallest share that meets
  your damage budget.
- **Reproducibility**: `finetune_mixed(replay=0)` equals `finetune` exactly because `mixed_batch` consumes the generator the
  same way; that equality is a cheap regression test for refactors of a training loop.
