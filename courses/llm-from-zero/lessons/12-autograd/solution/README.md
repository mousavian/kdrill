# Solution notes

- Every primitive is the same three lines: compute forward, remember parents, define a closure that does `+=` of (local derivative * upstream gradient). The `+=` is what makes reused values and diamonds correct.
- The derived operations (`-`, `/`, reflected versions) reuse the primitives, so there is no extra backward code to get wrong. Division is multiplication by `x ** -1`.
- `backward` uses an explicit stack, so a 20,000-operation chain is fine. It also zeroes the graph's grads first, so calling it again, or on a new root over the same leaves, never mixes in stale gradients.
- Try `neuron_demo.py` and then print `loss.data` per step: you just trained a model with gradients you wrote.
