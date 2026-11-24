# Solution notes

- **Tying** is one assignment; afterwards `parameters()` yields the shared matrix once, so `sum(p.numel())` is already the true count.
- **Two-pass initialisation**: first everything to `N(0, 0.02)`, then override the residual-writing projections. Doing it in the opposite order silently undoes the scaled init.
- `pos_emb(torch.arange(T))` has shape `(T, C)` and broadcasts across the batch when added; using `T` from the input (not `block_size`) lets short prompts through.
- Parameter formula: `V*C + T*C + L*(12C^2 + 10C) + 2C`. Check it against the code for several shapes; a mismatch is nearly always a forgotten bias or norm.
- The overfit test is deliberately about *memorising random tokens*: there is nothing to generalise, so a loss that does not go to about 0 means optimisation or wiring is broken.
