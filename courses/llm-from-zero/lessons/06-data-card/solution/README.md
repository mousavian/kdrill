# Solution notes

- **One global dedup, then a split by document.** Deduplicating before splitting means a paragraph shared by two books lives only in the first one, so it cannot leak across splits. The survivors are a subsequence of the input, which is how they are traced back to their book.
- **Statistics are measured on the written files**, not on in-memory variables, so the card describes what is actually on disk.
- **The card is generated** from `stats`; only `LIMITATIONS` is hand-written. The limitations in the reference are an example of the level of specificity expected: they name the author, period, size, cleaning side effects and the weakness of a one-book test set.
- Run `prepare_run.py` and compare your card's numbers with the reference ones on the same data.
