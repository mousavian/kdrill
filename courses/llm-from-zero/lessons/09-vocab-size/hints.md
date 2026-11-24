The three small metrics are one-liners; guard the empty cases. For `rare_fraction`, make `counts = [0] * len(tokenizer.merges)`, add one for every id in `ids` with `256 <= i < 256 + len(merges)`, and return the share of counts below `min_count`.
---
`study`: `top = BPE.train(train_text, max(sizes) - 256 - len(SPECIALS), SPECIALS)` once, then for every size `k = s - 256 - len(SPECIALS)` (clamped to between 0 and `len(top.merges)`) and `tok = BPE(top.merges[:k], SPECIALS)`. Encode `val_text` with that tokenizer and fill the row from the ids.
---
`choose_size`: filter the rows to those with `rare_fraction <= max_rare`, take the largest `vocab_size`; if the filter is empty, the smallest `vocab_size` of all rows. For the json, run `make py F=vocab_report.py` and quote the tokens per word, the rare fraction and the embedding parameters of the rows you compared.
