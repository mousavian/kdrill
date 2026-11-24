# Solution notes

- The backward pass is the forward pass read backwards, one line per forward line. Each line is "transpose of the layer input times the incoming gradient" for weights, "incoming gradient times transposed weights" for what goes further back, and `1 - h**2` through `tanh`.
- `np.add.at(dC, X, demb)` is not optional: a token that occurs in several positions of a batch, or in several rows, must add up its gradient. The test batches repeat tokens on purpose.
- `evaluate_loss` weights chunks by their size; averaging chunk means is wrong when the last chunk is shorter.
- Numbers on the bundled corpus (89 characters): uniform 4.49 nats, best bigram 2.39, this MLP about 1.98 after 6,000 steps in a few seconds. Longer context and bigger layers keep helping, until training loss and validation loss separate (lessons 15 and 23).
