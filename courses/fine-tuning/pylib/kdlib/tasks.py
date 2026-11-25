"""Corpora and synthetic tasks of the fine-tuning course: the same for every learner.

Text:   holmes(split) is the base model's world (Doyle), alice(split) the style to adapt to.
Format: a case-file question -> one-word answer task ("What colour is the lamp?" -> "grey"): 80 things,
        two facts each (colour, room), three phrasings per fact. The answer is a function of the question,
        so every example can be checked against the fact table.
Prefs:  the same questions answered tersely (preferred) or in a chatty Holmes voice (rejected).
Everything is generated from seeds; the committed jsonl files in data/ come from `hack/make_tasks.py`.
"""
import gzip
import json
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
EOS = "<|endoftext|>"


def _gz(name):
    with gzip.open(os.path.join(DATA, name), "rt", encoding="utf-8") as f:
        return f.read()


def holmes(split):
    return _gz("holmes_%s.txt.gz" % split)


def alice(split):
    return _gz("alice_%s.txt.gz" % split)


WORDS = """amber anchor apple arrow basket bell blanket bottle branch bridge candle carpet castle cellar chimney
cloak clock cloud coin copper cottage crown curtain dagger dawn diamond door dragon drawer dust ember engine
fabric feather fence field flame forest fountain garden gate glove goblet hammer harbour hat hill horse ink
iron ivory jacket jewel key kettle ladder lamp lantern leather letter library lock marble meadow mirror
mist moon needle novel oak orchard paper parcel pearl pebble pipe pillow pocket pond puzzle quill rabbit
raven ribbon river roof rope saddle sapphire scarlet shadow shelf silver slate smoke snow spoon staircase
star stone storm street table thimble thread tower trumpet umbrella valley velvet violin wagon walnut
watch willow window wire wool yard zinc brave calm clever cold crimson curious dark dusty eager faint
gentle golden grey heavy hollow humble idle jolly keen lively lonely mellow narrow noble odd pale polite
proud quick quiet rusty shy silent sleepy slender solemn steady stern strange swift tall tidy tiny warm
weary wicked wild wise young""".split()
assert len(WORDS) == len(set(WORDS)) >= 160

CHATTY = ("Elementary, my dear Watson: {a}", "I should say {a}, naturally", "Why, {a}, of course, and a most curious case it is",
          "You see, but you do not observe: {a}", "The game is afoot, and the answer is {a}")
CHATTY_MARKERS = ("Elementary", "I should say", "Why,", "You see", "game is afoot")


_NOUNS = sorted(WORDS[:WORDS.index("brave")])
ENTITIES = sorted(random.Random(0).sample(_NOUNS, 80))
COLOURS = ("red", "blue", "green", "yellow", "white", "black", "grey", "brown", "purple", "orange")
ROOMS = ("cellar", "attic", "kitchen", "study", "parlour", "hall", "garden", "stable")
TEMPLATES = {
    "colour": ("What colour is the {x}?", "Name the colour of the {x}.", "The {x} is which colour?"),
    "room": ("Where is the {x} kept?", "In which room is the {x}?", "Where would I find the {x}?"),
}
_rf = random.Random(1)
FACTS = {"colour": {x: _rf.choice(COLOURS) for x in ENTITIES}, "room": {x: _rf.choice(ROOMS) for x in ENTITIES}}


def _all():
    return [(attr, x, t.format(x=x), FACTS[attr][x]) for attr, temps in TEMPLATES.items() for x in ENTITIES for t in temps]


def all_questions():
    """Every question of the task: 80 things x 2 attributes x 3 phrasings = 480."""
    return [{"question": q, "answer": a} for _, _, q, a in _all()]


def expected_answer(q):
    """The rule: the true answer to a question of this task, or None when it is not one of its questions."""
    for attr, temps in TEMPLATES.items():
        for t in temps:
            head, tail = t.split("{x}")
            if q.startswith(head) and q.endswith(tail) and len(q) > len(head) + len(tail):
                x = q[len(head):len(q) - len(tail)] if tail else q[len(head):]
                if x in FACTS[attr]:
                    return FACTS[attr][x]
    return None


def train_eval_qa(n_eval=100, seed=1):
    """Disjoint train (380) and held-out (100) questions. Every fact stays in the training set with at
    least one phrasing; the held-out questions are phrasings the model has not seen asked this way."""
    rnd = random.Random(seed)
    by_fact = {}
    for attr, x, q, a in _all():
        by_fact.setdefault((attr, x), []).append({"question": q, "answer": a})
    facts = sorted(by_fact)
    rnd.shuffle(facts)
    ev = []
    for k in facts:                       # hold out one or two of the three phrasings of a fact
        ph = by_fact[k][:]
        rnd.shuffle(ph)
        ev += ph[:rnd.choice((1, 2))]
    ev = ev[:n_eval]
    held = {e["question"] for e in ev}
    tr = [e for e in all_questions() if e["question"] not in held]
    rnd.shuffle(tr)
    return tr, ev


def chatty(answer, rnd):
    return rnd.choice(CHATTY).format(a=answer)


def is_chatty(text):
    return any(m in text for m in CHATTY_MARKERS)


def make_pairs(examples, seed):
    """Preference pairs for questions: chosen = the terse answer, rejected = the chatty one (both correct)."""
    rnd = random.Random(seed)
    return [{"prompt": e["question"], "chosen": e["answer"], "rejected": chatty(e["answer"], rnd)} for e in examples]


def make_mixed_sft(examples, seed, chatty_share=0.5):
    """SFT examples where a share of the answers is chatty (the model that preference tuning then steers)."""
    rnd = random.Random(seed)
    out = []
    for e in examples:
        a = chatty(e["answer"], rnd) if rnd.random() < chatty_share else e["answer"]
        out.append({"question": e["question"], "answer": a})
    return out


def make_raw_qa(seed=3):
    """A messy raw file for the data-cleaning lesson. Returns (rows, truth) where rows are dicts and
    truth is the set of questions that are valid, unique, free of markers and short enough."""
    rnd = random.Random(seed)
    qs = train_eval_qa()[0]                          # never the held-out questions
    rnd.shuffle(qs)
    good = qs[:260]
    rows = [dict(e) for e in good]
    truth = {e["question"] for e in good}
    n = len(good)
    for i in range(14):                              # exact duplicates
        rows.append(dict(good[rnd.randrange(n)]))
    for i in range(10):                              # duplicates that differ only in spacing
        e = good[rnd.randrange(n)]
        rows.append({"question": "  " + e["question"].replace(" ", "  ") + " ", "answer": " " + e["answer"] + "  "})
    for i in range(8):                               # empty answers
        rows.append({"question": qs[260 + i]["question"], "answer": "   "})
    for i in range(8):                               # empty / missing questions
        rows.append({"question": rnd.choice(["", "  "]), "answer": rnd.choice(COLOURS)})
    for i in range(8):                               # far too long
        words = [rnd.choice(WORDS) for _ in range(40)]
        rows.append({"question": "What colour is the %s?" % " ".join(words), "answer": rnd.choice(COLOURS)})
    for i in range(6):                               # answer contains the end-of-text marker or a newline
        rows.append({"question": qs[280 + i]["question"], "answer": qs[280 + i]["answer"] + rnd.choice([" " + EOS, "\nQ: more"])})
    rnd.shuffle(rows)
    return rows, truth


def make_raw_pairs(seed=4):
    """A messy preference file for lesson 14. Returns (rows, truth): truth is the set of prompts that must survive
    (valid, unique, not an evaluation prompt)."""
    rnd = random.Random(seed)
    tr, ev = train_eval_qa()
    pool = tr[:]
    rnd.shuffle(pool)
    good = make_pairs(pool[:200], seed + 1)
    rows = [dict(p) for p in good]
    truth = {p["prompt"] for p in good}
    n = len(good)
    for i in range(10):                              # duplicate pairs
        rows.append(dict(good[rnd.randrange(n)]))
    for i in range(8):                               # chosen == rejected
        e = pool[200 + i]
        rows.append({"prompt": e["question"], "chosen": e["answer"], "rejected": e["answer"]})
    for i in range(8):                               # empty rejected / empty chosen
        e = pool[210 + i]
        rows.append({"prompt": e["question"], "chosen": e["answer"] if i % 2 else "  ", "rejected": "  " if i % 2 else e["answer"]})
    for i in range(10):                              # labels swapped: the chatty answer is marked as chosen
        p = make_pairs([pool[220 + i]], seed + 50 + i)[0]
        rows.append({"prompt": p["prompt"], "chosen": p["rejected"], "rejected": p["chosen"]})
    for i in range(8):                               # the rejected answer is about something else (not an answer to this prompt)
        p = make_pairs([pool[240 + i]], seed + 70 + i)[0]
        j = 250 + i
        while pool[j]["answer"] in p["chosen"] or p["chosen"] in pool[j]["answer"]:
            j += 1
        p["rejected"] = make_pairs([pool[j]], seed + 90 + i)[0]["rejected"]
        rows.append(p)
    for i in range(8):                               # prompts of the evaluation set (leakage)
        rows.append(make_pairs([ev[i]], seed + 110 + i)[0])
    rnd.shuffle(rows)
    return rows, truth


def make_noisy_qa(n=300, noise=0.35, seed=5):
    """(rows, is_clean) for the quality lesson: examples whose answer is wrong for `noise` of them."""
    rnd = random.Random(seed)
    qs = train_eval_qa()[0]                          # never the held-out questions
    rnd.shuffle(qs)
    rows, flags = [], []
    for e in qs[:n]:
        if rnd.random() < noise:
            pool = COLOURS if e["answer"] in COLOURS else ROOMS
            rows.append({"question": e["question"], "answer": rnd.choice([w for w in pool if w != e["answer"]])})
            flags.append(False)
        else:
            rows.append(dict(e))
            flags.append(True)
    return rows, flags


def write_jsonl(path, rows):
    with open(path, "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")


def read_jsonl(path):
    with open(path, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]
