"""Lesson 07 - reference solution."""
import json

TEMPLATES = {
    "colour": ["What colour is the {x}?", "Name the colour of the {x}.", "The {x} is which colour?"],
    "room": ["Where is the {x} kept?", "In which room is the {x}?", "Where would I find the {x}?"],
}


def load_facts(path="data/facts.json"):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def parse_question(q):
    for attr, temps in TEMPLATES.items():
        for t in temps:
            head, tail = t.split("{x}")
            if len(q) > len(head) + len(tail) and q.startswith(head) and q.endswith(tail):
                return attr, q[len(head):len(q) - len(tail)]
    return None


def is_consistent(example, facts):
    p = parse_question(example.get("question", ""))
    if p is None:
        return False
    attr, thing = p
    return facts.get(attr, {}).get(thing) == example.get("answer")


def split_clean(rows, facts):
    kept, dropped = [], []
    for r in rows:
        (kept if is_consistent(r, facts) else dropped).append(r)
    return kept, dropped


def noise_rate(rows, facts):
    if not rows:
        return 0.0
    return len(split_clean(rows, facts)[1]) / len(rows)
