"""Lesson 27 - the capstone: raw text in, trained model + checkpoint + model card out.

Everything here is YOUR code from earlier lessons: prepare.build_dataset (06), bpe.BPE (08),
gpt.GPT (21), train_gpt.train_run (22), generate.generate (24), evaluation (26).
Keep the imports exactly as they are: the tests look at them.
"""
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
    merges=100,                       # BPE merges (vocabulary = 256 + merges + 1 special token)
    block_size=32, n_layer=2, n_head=2, n_embd=48, dropout=0.0,
    batch_size=16, max_steps=150, warmup_steps=10, max_lr=4e-3, min_lr=4e-4,
    weight_decay=0.1, grad_clip=1.0, eval_every=50, eval_iters=5, save_every=1000,
    seed=0, sample_tokens=60,
)


def run_pipeline(raw_dir, out_dir, config=None):
    """Run the whole thing on the *.txt files in raw_dir. `config` overrides DEFAULT_CONFIG keys.

    1. build_dataset(raw_dir, out_dir/data, seed=cfg["seed"]) -> data/train.txt, val.txt, test.txt, DATA_CARD.md
    2. Train a BPE tokenizer with cfg["merges"] merges on the TRAIN text only (BPE.train).
    3. Encode the three splits with it into 1-D LongTensors.
    4. torch.manual_seed(cfg["seed"]); model = GPT(vocab, block_size, n_layer, n_head, n_embd, dropout).
    5. train_run(model, train_ids, val_ids, cfg, out_dir/run) on train and val ONLY, passing exactly the
       encoded train and validation splits. cfg for train_run needs the keys block_size, batch_size,
       max_steps, warmup_steps, max_lr, min_lr, weight_decay, grad_clip, eval_every, eval_iters,
       save_every, seed: the DEFAULT_CONFIG has them.
    6. Only now touch the test split: perplexity_on_text(model, test_ids, stride=block_size // 2),
       and bits_per_char(loss, tokens, number of characters of the test text).
    7. Three samples: generate(model, prompt, cfg["sample_tokens"], temperature=0.8, top_k=20,
       generator=torch.Generator().manual_seed(cfg["seed"] + i)) for i in 0, 1, 2, where the prompt is
       the first 8 tokens of validation text window i (val_ids[i * 50 : i * 50 + 8]); decode them to text.
    8. Write out_dir/checkpoint.pt (see below) and out_dir/MODEL_CARD.md (make_model_card).
    9. Return {"checkpoint": path, "model_card": path, "val_loss": the last validation loss of the
       run, "test_loss", "test_perplexity", "bits_per_char", "n_params", "vocab_size", "samples": [str, str, str]}.

    The checkpoint (torch.save of a dict) is the handoff to the fine-tuning course:
      "model_state"  model.state_dict()
      "gpt_config"   {"vocab_size", "block_size", "n_layer", "n_head", "n_embd", "dropout"}
      "tokenizer"    tokenizer.to_dict()
      "metrics"      {"val_loss", "test_loss", "test_perplexity", "bits_per_char"}
      "train_config" the full cfg used
      "data_card"    the text of out_dir/data/DATA_CARD.md
      "course"       "llm-from-zero"
    """
    # TODO
    raise NotImplementedError


def load_for_finetuning(path):
    """Rebuild (model, tokenizer) from a checkpoint written by run_pipeline: a GPT built from
    "gpt_config" with the saved weights loaded, in eval mode, and a BPE from "tokenizer"."""
    # TODO
    raise NotImplementedError


def make_model_card(info):
    """Markdown model card. `info` has: n_params, vocab_size, gpt_config, train_config, steps (number of
    optimizer steps), metrics (val_loss, test_loss, test_perplexity, bits_per_char), samples (list of str),
    data_card (text). Sections, with exactly these headings and in this order:
      # Model card
      ## Model                          architecture, parameter count, vocabulary size, context length
      ## Training data                  a short summary taken from the data card (its first heading's
                                        sources/sizes are fine: quote the data card's "## Sources" and
                                        "## Splits" sections) and a pointer to DATA_CARD.md
      ## Training                       steps, batch size, learning-rate schedule, optimizer, seed
      ## Evaluation                     validation loss, test loss, test perplexity (2 decimals),
                                        bits per character; say it is measured on the held-out test split
      ## Samples                        the generated samples, each in a block quote or code block
      ## Intended use and limitations   written by you in your own words: what it is for and what it is not
    Every number above must appear as plain digits."""
    # TODO
    raise NotImplementedError
