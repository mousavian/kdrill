# Solution notes

- `causal_mean` is attention with uniform weights, and the triangular matrix is the mask: the same `tril` idea is the causal mask of the real attention.
- The mask is applied to the *scores* with `-inf`, before the softmax, never to the weights after it: after the softmax the rows would no longer sum to 1. `exp(-inf)` is exactly 0.
- The mask is built from the input's `T`, not from `block_size`, so a short prompt works. `block_size` only limits the longest sequence (and the position embeddings of lesson 21).
- Dropout goes on the attention weights, after the softmax; `att` returned for inspection is the pre-dropout version.
- Run `attention_demo.py`: with random weights each row is close to uniform over the allowed positions. Training is what makes some of them peak.
