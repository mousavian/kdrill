# Solution notes

- **Track what is already scored.** With overlapping windows the number of new tokens in a window is `end - scored_upto`: the stride for full windows and fewer for the short last one. That bookkeeping is what guarantees `len(ids) - 1` scored tokens, and the table-model test verifies it for eight block/stride combinations.
- **Context versus compute.** Stride 1 gives every token a full window of context at `block_size` times the cost; the GPT test shows a small stride never loses to non-overlapping windows.
- `continuation_logprob` uses one forward pass over the whole sequence: causal masking means position `t` only used earlier tokens, so a single pass gives all the conditional probabilities.
- Probes sum log-probs of *different-length* continuations; that favours short ones. Real probe suites normalise by length or compare same-length alternatives, which is worth noticing when you write your own.
- The blinded sheet separates what a judge sees (two anonymous samples) from the key that unblinds it; swapping order per prompt with a seeded coin removes position bias.
