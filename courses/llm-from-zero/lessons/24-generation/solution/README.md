# Solution notes

- **Top-k keeps ties** because the threshold is the k-th *value*, not the k-th index; that is also what `torch.topk`-based implementations in the wild do.
- **Top-p keeps the token that crosses `p`**: the rule is "cumulative probability of the tokens ranked *above* it is below p", i.e. `cumsum - probs < p`. That also guarantees the best token always survives, so the distribution is never empty.
- Order of operations matters: penalty first (it changes which token is best, even for greedy), then temperature, then the filters, then the softmax. Filtering before temperature would cut a different set.
- `temperature == 0` is special-cased, because dividing by zero is not "very sharp", it is `inf`/`nan`.
- Cropping with `idx[:, -block_size:]` is what lets generation run past the context length; the model forgets the oldest tokens. The KV-cache trick in production only changes how fast this is, not what it computes.
