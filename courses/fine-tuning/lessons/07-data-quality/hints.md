`parse_question`: for every attribute and template, `head, tail = template.split("{x}")`. The question matches when `q.startswith(head) and q.endswith(tail)` and `len(q) > len(head) + len(tail)` (a non-empty thing); then the thing is `q[len(head):len(q) - len(tail)]`. Return `(attribute, thing)` for the first match, otherwise `None`. Do not strip or lower-case the question.
---
`is_consistent`: `p = parse_question(example.get("question", ""))`; if `p is None` return `False`; then `facts.get(attr, {}).get(thing) == example.get("answer")`. A missing answer or an unknown thing gives `None != ...`, so it is not consistent. Compare with `==` and nothing else.
---
`split_clean` is a single loop appending each row (the same dict object) to `kept` or `dropped`; `noise_rate` is `len(dropped) / len(rows)` with a guard for the empty list. If the outcome test says the validated data is not better, print `noise_rate` of the noisy file first: it should be around a third.
