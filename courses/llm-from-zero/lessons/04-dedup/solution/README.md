# Solution notes

- `exact_dedup` keeps 16-byte hashes of the normalised paragraphs, never the paragraphs themselves.
- `near_dedup` is the inverted index idea: `index[shingle] -> positions of kept paragraphs`. A new paragraph is only compared with kept paragraphs that share at least one shingle, so the work is proportional to real overlap, not to n squared. A dropped paragraph is not indexed, so near-copies chain to the earliest kept original, never to each other.
- Counting order matters for the statistics: junk first, then exact, then near. The same paragraph is never counted twice.
- On the real corpus the step removes only a few percent. That is a result worth putting in the data card, not a reason to skip the step: in a bigger crawl it is routinely 10-30 percent.
