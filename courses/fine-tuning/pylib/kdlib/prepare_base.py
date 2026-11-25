"""Choose the base model of the course: base/checkpoint.pt in the workspace (/work).

    python -m kdlib.prepare_base          (run by the course setup, inside the container)

Your llm-from-zero capstone checkpoint (copied to /work/base/learner_checkpoint.pt by setup.sh) is used
when it loads into the course's GPT with exactly its parameter names, its tokenizer has the end-of-text
token, and its context is long enough for the tasks (MIN_BLOCK tokens). Otherwise the reference base model
that ships with the course is used and base/SOURCE.txt says why.
"""
import os
import shutil
import sys

import torch

from kdlib import refmodel as R
from kdlib import tasks as T

MIN_BLOCK = 64
WORK = "/work"


def check(path):
    """None when the checkpoint is usable, else the reason it is not."""
    try:
        ck = torch.load(path, weights_only=False, map_location="cpu")
        cfg, tok = ck["gpt_config"], R.BPE.from_dict(ck["tokenizer"])
        if T.EOS not in tok.special_ids:
            return "its tokenizer has no %s token" % T.EOS
        if cfg["block_size"] < MIN_BLOCK:
            return "its context is %d tokens, the tasks need at least %d (rerun your capstone with block_size=64)" % (cfg["block_size"], MIN_BLOCK)
        if cfg["vocab_size"] != tok.vocab_size:
            return "vocab_size does not match its tokenizer"
        R.GPT(**cfg).load_state_dict(ck["model_state"], strict=True)
    except Exception as e:  # noqa: BLE001
        return "it could not be loaded (%s)" % str(e).splitlines()[0][:120]
    return None


def main():
    base = os.path.join(WORK, "base")
    os.makedirs(base, exist_ok=True)
    dst = os.path.join(base, "checkpoint.pt")
    mine = os.path.join(base, "learner_checkpoint.pt")
    why = None
    if os.path.exists(mine):
        why = check(mine)
        if why is None:
            shutil.copyfile(mine, dst)
            note = "your llm-from-zero capstone model (out/capstone/checkpoint.pt)"
    else:
        why = "no capstone checkpoint found at ~/kdrill-work/llm-from-zero/out/capstone/checkpoint.pt"
    if why is not None:
        shutil.copyfile(os.path.join(T.DATA, "ref_base.pt"), dst)
        note = "the reference base model that ships with the course (%s)" % why
    with open(os.path.join(base, "SOURCE.txt"), "w") as f:
        f.write(note + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
