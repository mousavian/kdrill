# Solution notes

- **Merging is one algebraic identity**: `W x + s B A x = (W + s B A) x` with `s = alpha / r`. Everything else is bookkeeping:
  same bias, same names, same shapes.
- **Compare logits, not just the loss**: equal losses can hide compensating errors; equal logits on random token batches
  across every layer type (attention heads, projection, both MLP layers) cannot.
- **Tolerance**: float32 results differ in the last digits because the two orders of summation round differently; `1e-4` is
  tight enough to catch a wrong scale (which gives errors of order `1e-1`) and loose enough to pass honest rounding.
- **Do not modify the caller's model** when saving: `save_merged_checkpoint` merges a copy, so a later `save_adapter` still works.
- **Keep the adapter if you may change your mind.** A merged checkpoint cannot be un-merged without the adapter file, which is
  why the demo saves both.
