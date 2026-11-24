# Solution notes

- `get_lr` uses `step + 1` in warm-up so the very first step has a non-zero rate, and clamps to `min_lr` after `max_steps` so a run that goes slightly past the schedule does not start to rise again.
- `clip_grad_norm` computes one global norm over every parameter's gradient and multiplies all of them by one factor. Clipping each tensor separately would change the update direction.
- The checkpoint holds five things beyond the weights: optimizer state, step, config, global RNG and the data generator. The resume test uses dropout on purpose, because dropout masks come from the global RNG: without `torch_rng` in the checkpoint the two runs diverge at the first dropped unit.
- Evaluation uses its own fixed generator, so it neither consumes the training generator nor the global RNG: an evaluation schedule can change without changing the training trajectory.
- The long run on real data (`run_train.py`) ends around a validation loss of 1.6 nats per character (1.59 at step 1250 in the reference run); compare it with the bigram's 2.4 and the MLP's 2.0.
