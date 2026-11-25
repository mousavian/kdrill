# Solution notes

- **Scale per row** costs one float per output unit (a few percent of the weight bytes) and keeps one large weight from
  squeezing the resolution of every other row; the outlier test shows the difference directly.
- **Buffers, not parameters**: the quantised weights are `register_buffer`s so they are saved with the model, move with
  `.to(device)`, and are invisible to the optimizer; gradients still flow *through* `x @ dequantize(...)` to whatever sits before
  the layer, which is how adapters on a quantised base can learn.
- **Zero rows** need a safe scale (1.0), or you divide by zero and get NaNs.
- **Order of operations in QLoRA**: add adapters, then quantise what sits under them; the adapters stay float32 and trainable (same
  count as before quantising), the integer codes are bit-identical after training.
- **What the table shows**: int8 is almost free in loss and saves most of the matrix bytes; 4-bit costs real loss on a model this small,
  and the adapters recover a good part of it while learning the style at the same time.
