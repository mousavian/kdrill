"""Lesson 27 - reference solution."""
import hashlib
import json
import math
import os

import torch

from bpe import BPE
from evaluation import bits_per_char, perplexity_on_text
from generate import generate
from gpt import GPT
from prepare import build_dataset
from train_gpt import train_run

DEFAULT_CONFIG = dict(
    merges=100,
    block_size=32, n_layer=2, n_head=2, n_embd=48, dropout=0.0,
    batch_size=16, max_steps=150, warmup_steps=10, max_lr=4e-3, min_lr=4e-4,
    weight_decay=0.1, grad_clip=1.0, eval_every=50, eval_iters=5, save_every=1000,
    seed=0, sample_tokens=60,
)

_TRAIN_KEYS = ("block_size", "batch_size", "max_steps", "warmup_steps", "max_lr", "min_lr", "weight_decay",
               "grad_clip", "eval_every", "eval_iters", "save_every", "seed")


def _read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def run_pipeline(raw_dir, out_dir, config=None):
    cfg = dict(DEFAULT_CONFIG)
    cfg.update(config or {})
    data_dir = os.path.join(out_dir, "data")
    build_dataset(raw_dir, data_dir, seed=cfg["seed"])
    text = {s: _read(os.path.join(data_dir, s + ".txt")) for s in ("train", "val", "test")}

    tok = BPE.train(text["train"], cfg["merges"])
    ids = {s: torch.tensor(tok.encode(t), dtype=torch.long) for s, t in text.items()}

    gpt_config = {"vocab_size": tok.vocab_size, "block_size": cfg["block_size"], "n_layer": cfg["n_layer"],
                  "n_head": cfg["n_head"], "n_embd": cfg["n_embd"], "dropout": cfg["dropout"]}
    torch.manual_seed(cfg["seed"])
    model = GPT(**gpt_config)
    run = train_run(model, ids["train"], ids["val"], {k: cfg[k] for k in _TRAIN_KEYS}, os.path.join(out_dir, "run"))
    val_loss = run["evals"][-1]["val_loss"]

    r = perplexity_on_text(model, ids["test"], stride=cfg["block_size"] // 2)
    bpc = bits_per_char(r["loss"], r["tokens"], len(text["test"]))

    samples = []
    for i in range(3):
        prompt = ids["val"][i * 50:i * 50 + 8][None]
        out = generate(model, prompt, cfg["sample_tokens"], temperature=0.8, top_k=20,
                       generator=torch.Generator().manual_seed(cfg["seed"] + i))
        samples.append(tok.decode(out[0].tolist()))

    metrics = {"val_loss": val_loss, "test_loss": r["loss"], "test_perplexity": r["perplexity"], "bits_per_char": bpc}
    data_card = _read(os.path.join(data_dir, "DATA_CARD.md"))
    ck_path = os.path.join(out_dir, "checkpoint.pt")
    torch.save({"model_state": model.state_dict(), "gpt_config": gpt_config, "tokenizer": tok.to_dict(),
                "metrics": metrics, "train_config": cfg, "data_card": data_card, "course": "llm-from-zero"}, ck_path)
    card_path = os.path.join(out_dir, "MODEL_CARD.md")
    with open(card_path, "w", encoding="utf-8") as f:
        f.write(make_model_card({"n_params": model.num_params(), "vocab_size": tok.vocab_size, "gpt_config": gpt_config,
                                 "train_config": cfg, "steps": cfg["max_steps"], "metrics": metrics,
                                 "samples": samples, "data_card": data_card}))
    return {"checkpoint": ck_path, "model_card": card_path, "val_loss": val_loss, "test_loss": r["loss"],
            "test_perplexity": r["perplexity"], "bits_per_char": bpc, "n_params": model.num_params(),
            "vocab_size": tok.vocab_size, "samples": samples}


def load_for_finetuning(path):
    ck = torch.load(path, weights_only=False)
    model = GPT(**ck["gpt_config"])
    model.load_state_dict(ck["model_state"])
    model.eval()
    return model, BPE.from_dict(ck["tokenizer"])


def _section(card, name):
    """the text of '## <name>' in a markdown document ('' if missing)"""
    parts = card.split("\n## ")
    for p in parts[1:]:
        if p.startswith(name + "\n"):
            return p[len(name) + 1:].strip()
    return ""


def make_model_card(info):
    g, t, m = info["gpt_config"], info["train_config"], info["metrics"]
    out = ["# Model card", "",
           "## Model", "",
           "A decoder-only transformer (GPT) trained from scratch in the llm-from-zero course.", "",
           "- parameters: %d" % info["n_params"],
           "- layers: %d, heads: %d, embedding size: %d" % (g["n_layer"], g["n_head"], g["n_embd"]),
           "- context length: %d tokens" % g["block_size"],
           "- vocabulary: %d tokens (byte-level BPE with %d merges)" % (info["vocab_size"], t["merges"]), "",
           "## Training data", "",
           "Summary of DATA_CARD.md (the full card is next to the data):", "",
           "### Sources", "", _section(info["data_card"], "Sources"), "",
           "### Splits", "", _section(info["data_card"], "Splits"), "",
           "## Training", "",
           "- optimizer steps: %d, batch size: %d sequences of %d tokens" % (info["steps"], t["batch_size"], g["block_size"]),
           "- AdamW, weight decay %g, gradient clipping at %g, seed %d" % (t["weight_decay"], t["grad_clip"], t["seed"]),
           "- learning rate: %d warm-up steps to %g, then cosine decay to %g" % (t["warmup_steps"], t["max_lr"], t["min_lr"]), "",
           "## Evaluation", "",
           "Measured on the held-out test split, which was not used for any decision:", "",
           "- validation loss at the end of training: %.4f nats per token" % m["val_loss"],
           "- test loss: %.4f nats per token" % m["test_loss"],
           "- test perplexity: %.2f" % m["test_perplexity"],
           "- bits per character: %.3f" % m["bits_per_char"], "",
           "## Samples", ""]
    for i, s in enumerate(info["samples"]):
        out += ["Sample %d:" % (i + 1), "", "```", s, "```", ""]
    out += ["## Intended use and limitations", "",
            "This model exists for learning: it shows the whole path from raw text to a working language model, and it is "
            "the starting point for the fine-tuning exercises. It is not a product. It was trained on a few million "
            "characters of a single genre, so it imitates the style of that data, repeats itself, invents facts, and "
            "knows nothing outside it. It has no safety training. Do not use its output as information, and expect "
            "the biases and period attitudes of the source texts to show in what it writes.", ""]
    return "\n".join(out)
