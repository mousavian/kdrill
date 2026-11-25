# Solution notes

- **Zero B, random A**: the adapted model equals the base at step 0, so the first loss is the base loss and training
  can only move away from a good place deliberately. `A.grad` is zero at the start because `dL/dA` is multiplied by `B`.
- **Walk the tree on a snapshot** (`list(model.named_modules())`) because wrapping replaces children while you iterate; the
  `isinstance(mod, LoRALinear)` skip stops the walk from wrapping the wrapper's own `base`.
- **The count formula** `r * (in + out)` per wrapped layer is what verify checks against `trainable_count`; the per-head
  `query/key/value` layers are only 96 by 24, so a rank of 8 is already a third of their size.
- **The adapter file holds A, B, r, alpha** and nothing of the base; `load_adapter` validates names and shapes first so a
  mismatched file cannot leave the model half-loaded.
- **Why `alpha / r`**: with the scale fixed by `alpha`, a larger rank gives more directions, not a larger step per direction.
