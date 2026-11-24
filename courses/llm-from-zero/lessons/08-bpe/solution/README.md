# Solution notes

- **Training counts chunks, not characters**: `Counter` of `tuple(bytes)` per pre-token. A merge touches every *distinct* chunk once, so 300 merges on 150 KB take seconds.
- **Tie-break**: `key=(count, -left, -right)` with `max` is "highest count, then smallest pair". Any fixed rule works as long as it is deterministic; the tests fix this one so merges can be compared.
- **Encoding picks the lowest-rank pair present each round**, which is the same as replaying merges in training order but touches only pairs that exist in the chunk.
- **Specials are ids after the merges** and are cut out before pre-tokenization, so training never sees them.
- Look at the first merges on your real training split: `t`+`h`, space+`t`, `he`... Then at the last ones: rarer, longer names and words. That ordering is the whole idea.
