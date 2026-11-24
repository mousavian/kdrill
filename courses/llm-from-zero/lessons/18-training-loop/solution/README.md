# Solution notes

- `torch.randint(0, len(data) - block_size, ...)` is the whole boundary argument: the largest start is `len - block_size - 1`, whose target window ends exactly at the last token.
- The evaluation helper is wrapped in `torch.no_grad()` and restores `model.training`, so it can be called from the middle of training without side effects. The fixed evaluation generator (seed 1234) means the curve is not jittered by which batches happened to be drawn.
- The training generator is used only for training batches. Evaluating therefore does not change which batches training sees: a run with evaluations every 10 steps trains exactly like one with none (the reference-loop test relies on this).
- A bigram trained this way approaches the loss of the counting model of lesson 10 (about 2.4 nats on the bundled data) given enough steps: the loop is right when it heads there.
