# Solution notes

- **Work on a copy.** `clone(base)` per run keeps the sweep honest; the test runs the same configuration alone and after
  another one and requires the same loss.
- **Seeds are part of the setting**: the adapter's initial `A` (through `add_lora(seed=...)`) and the batch order
  (`finetune(seed=...)`) are both fixed, so differences between rows are the settings, not luck. (Lesson 16 shows how large
  the luck can be.)
- **Rank buys capacity; alpha buys speed.** In the reference sweep the loss falls by about 0.04 nats per doubling of the rank
  up to 16 (no plateau at this budget), and rank 8 with `alpha = 1` is clearly behind rank 8 with `alpha = 16` at the same
  number of steps. Whether returns diminish further out is not something this sweep can tell you.
- **The selection rule is explicit and tie-broken** so the same table always gives the same answer.
