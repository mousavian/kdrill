`fit`: `ids = np.asarray(ids)`; the pair id is `ids[:-1] * V + ids[1:]`; `np.bincount(pair, minlength=V*V).reshape(V, V)` is the whole count matrix. Handle fewer than two ids (all zeros).
---
`probs`: `c = self.counts + self.smoothing`; `tot = c.sum(axis=1, keepdims=True)`; divide where `tot > 0`, and put `1 / V` in the rows where it is 0 (`np.where` or a boolean mask). `top_next`: `sorted(range(V), key=lambda j: (-row[j], j))[:k]` gives ties to the lower id.
---
`sample`: `rng = np.random.default_rng(seed)`, `P = self.probs()` once, then loop `n` times: `cur = int(rng.choice(V, p=P[cur]))`, append `cur`. Return Python ints, not numpy ints.
