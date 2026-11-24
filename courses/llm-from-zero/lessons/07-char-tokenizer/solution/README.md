# Solution notes

- Two views of the same vocabulary, `chars` (id to character) and `stoi` (character to id), both derived from `sorted(set(text))`; `from_dict` recomputes `stoi` so they can never disagree.
- Reserved ids come first, so adding a special token later does not shift any real id.
- `unk_rate` on the validation split is the number to watch: if it is not about zero the vocabulary was built from too little or the wrong text.
- Run it on your real training split: about 80 symbols, roughly 4 million tokens for the whole corpus. Compare that sequence length with what BPE achieves next.
