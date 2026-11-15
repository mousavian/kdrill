"""Generate text from a trained model.

  python sample.py --model /ckpt              # newest checkpoint in a directory
  python sample.py --model /models/run-1      # model.pt written by --model-out
  python sample.py --model s3://bucket/prefix # same, from object storage

Prints the sample and, with --out, writes it to a file as well.
"""
import argparse
import io
import os
import sys

import torch

from model import GPT, GPTConfig
from store import open_store


def load(location):
    if location.endswith(".pt") and os.path.isfile(location):
        return torch.load(location, weights_only=False), location
    st = open_store(location)
    if st.get("model.pt") is not None:
        return torch.load(io.BytesIO(st.get("model.pt")), weights_only=False), f"{location}/model.pt"
    name = (st.get("latest") or b"").decode().strip()
    if not name or st.get(name) is None:
        names = st.list("ckpt-")
        name = names[-1] if names else ""
    if not name:
        raise SystemExit(f"error: no model.pt and no checkpoint in {location}")
    return torch.load(io.BytesIO(st.get(name)), weights_only=False), f"{location}/{name}"


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--model", default=os.environ.get("MODEL", ""), required=not os.environ.get("MODEL"))
    p.add_argument("--chars", type=int, default=int(os.environ.get("SAMPLE_CHARS", 300)))
    p.add_argument("--prompt", default=os.environ.get("PROMPT", "ROMEO:"))
    p.add_argument("--temperature", type=float, default=float(os.environ.get("TEMPERATURE", 0.8)))
    p.add_argument("--seed", type=int, default=int(os.environ.get("SEED", 7)))
    p.add_argument("--out", default=os.environ.get("SAMPLE_OUT", ""))
    a = p.parse_args()
    torch.set_num_threads(int(os.environ.get("OMP_NUM_THREADS", 1)))
    ck, where = load(a.model)
    cfg = GPTConfig(**ck["config"])
    model = GPT(cfg)
    model.load_state_dict(ck["model"])
    model.eval()
    chars = ck["chars"]
    stoi = {c: i for i, c in enumerate(chars)}
    prompt = "".join(c for c in a.prompt if c in stoi) or chars[0]
    idx = torch.tensor([[stoi[c] for c in prompt]])
    g = torch.Generator().manual_seed(a.seed)
    out = model.generate(idx, a.chars, a.temperature, generator=g)[0].tolist()
    text = "".join(chars[i] for i in out)
    step = ck.get("step", "final")
    print(f"--- sample from {where} (step {step}, {model.num_params()} parameters) ---")
    print(text)
    if a.out:
        os.makedirs(os.path.dirname(a.out) or ".", exist_ok=True)
        with open(a.out, "w") as f:
            f.write(text + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
