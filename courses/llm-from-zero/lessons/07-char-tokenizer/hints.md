Keep two structures: `chars` (a list, the id order) and `stoi` (a dict from character to id). `fit`: `self.chars = sorted(set(text))`, then `self.stoi = {c: i + 2 for i, c in enumerate(self.chars)}`; return `self`.
---
`encode`: `[self.stoi.get(c, UNK) for c in text]` handles unknown characters in one expression. `decode`: loop over ids, skip `PAD`, map `UNK` to `UNK_CHAR`, map `2 <= i < vocab_size` to `self.chars[i - 2]`, otherwise `raise ValueError`. Convert each id with `int(i)` so numpy integers also work later.
---
`to_dict` returns `{"type": "char", "chars": list(self.chars)}`; `from_dict` builds a new instance and recomputes `stoi` from the list, so there is one source of truth. `save`/`load` are `json.dump`/`json.load` with `encoding="utf-8"`.
