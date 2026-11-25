# Solution notes

- **The mask lives on the targets.** `mask[r, plen - 1:n] = 1` is the whole alignment: input position `plen - 1` is the
  last prompt token (`:`), and the thing it predicts is the first answer token. Writing `plen` instead is the classic off-by-one.
- **Zero gradient at prompt positions is a property you can assert**, not a hope: the test back-propagates through the
  real model and checks `logits.grad` is exactly zero wherever the mask is zero. (The prompt still shapes the answer
  through attention; masking only removes it as a *target*.)
- **Padding is invisible twice**: mask 0 for the loss, and right-padding for causal attention means the real tokens never
  attend to it.
- **Normalise by selected tokens**; dividing by `B * L` makes the effective learning rate depend on prompt length.
- **Masking is correct by construction, not always faster here**: with 20-token examples the two runs are within seed noise
  of each other (the answers are most of what has to be learned either way). Check the claim with seeds before you believe one run.
- **Format is learned long before correctness.** After 150 steps nearly every answer is in the right shape; exact match keeps
  climbing for several hundred more because the facts have to be memorised.
