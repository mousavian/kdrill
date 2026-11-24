import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")


def load_sources():
    with open(os.path.join(DATA, "sources.json"), encoding="utf-8") as f:
        return json.load(f)["books"]
