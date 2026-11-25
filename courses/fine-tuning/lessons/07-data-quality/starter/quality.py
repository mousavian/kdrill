"""Lesson 07 - data quality: validate answers against a trusted fact table, keep only the consistent examples."""
import json

# The questions of the task: {x} is the thing asked about. Both attributes, three phrasings each.
TEMPLATES = {
    "colour": ["What colour is the {x}?", "Name the colour of the {x}.", "The {x} is which colour?"],
    "room": ["Where is the {x} kept?", "In which room is the {x}?", "Where would I find the {x}?"],
}


def load_facts(path="data/facts.json"):
    """{"colour": {thing: colour}, "room": {thing: room}}: the trusted answers (finished)."""
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def parse_question(q):
    """(attribute, thing) for a question that matches one of the TEMPLATES exactly, else None.
    'What colour is the lamp?' -> ('colour', 'lamp'); 'Where is the lamp kept?' -> ('room', 'lamp').
    The thing must be non-empty. Anything that does not match a template, however close, is None."""
    # TODO
    raise NotImplementedError


def is_consistent(example, facts):
    """True when the question parses, the thing is in the fact table for that attribute, and the example's answer
    equals the fact exactly (no stripping, no case folding)."""
    # TODO
    raise NotImplementedError


def split_clean(rows, facts):
    """(kept, dropped): the rows (dicts, unchanged, in order) that are consistent and the rows that are not."""
    # TODO
    raise NotImplementedError


def noise_rate(rows, facts):
    """The share of rows that are not consistent (0.0 for an empty list)."""
    # TODO
    raise NotImplementedError
