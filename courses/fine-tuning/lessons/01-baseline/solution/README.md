# Solution notes

`solution/harness.py` is a complete implementation. Points to compare with yours:

- **Token-weighted loss**: sum the per-token losses (`reduction="sum"`) and divide by the number of targets once;
  averaging per-window means over-weights the short last window.
- **Every token but the first is predicted once**: windows do not overlap, so there is no double counting, but the
  first token of each window is predicted with less context than the last (a small bias that a sliding window with
  overlap would remove, at the cost of more computation).
- **Greedy decoding** is deterministic, which is what makes "exact match" a repeatable number.
- **Crop from the left**: the model only knows `block_size` positions, so a longer prompt loses its beginning.
- **Format and correctness are separate numbers.** A model can learn the format long before it learns the answers;
  lessons 02 and 06 show exactly that.
