# Solution notes

`solution/clean.py` is a complete implementation. Compare:

- **Order**: contents removal runs before `normalize`, because `normalize` collapses blank lines and the contents block is recognised by a gap of three blank lines.
- **Lazy regex for the start marker** (`.*?`, `re.S`): a title that wraps over two lines is still inside the marker.
- **`drop_contents` loops** and re-checks the same index after cutting, so two headings in a row are both handled.
- **Idempotence** comes for free when every rule only removes or canonicalises: a second pass finds nothing left to do.
- What it deliberately does *not* do: it keeps accented letters (`caf\u00e9`) and the few real symbols. Whether to go ASCII-only is a modelling decision, not a cleaning accident: lesson 06 asks you to write it down in the data card.
