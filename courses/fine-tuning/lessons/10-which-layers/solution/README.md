# Solution notes

- **The formula is exact**: each adapted layer adds `r * in` (for A) plus `out * r` (for B). Summing it over the wrapped layers
  predicts the trainable count to the last parameter; the test compares it with the real count for every group.
- **Ablate one thing at a time**: `compare_targets` keeps data, steps, rank, alpha and seed identical across groups, so the
  difference in the table is the placement.
- **Format versus facts**: every row learns the format (the attention adapters are enough to route and stop), but exact match
  depends on whether the adapters reach the layers that store the answers. That is why a parameter count alone never tells you
  which placement to pick.
- **Cost**: attention+MLP is 62,208 trainable parameters against 23,040 for qv; whether the extra accuracy is worth the extra
  adapter size is a product decision, and now you have the numbers for it.
