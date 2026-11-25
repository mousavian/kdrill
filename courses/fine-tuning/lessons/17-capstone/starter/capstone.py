"""Lesson 17 - the capstone pipeline. Everything here is YOUR code from earlier lessons: sft_data (05), masking (06),
lora (08), harness (01), trust (16), base (given). Keep the imports as they are: the tests look at them.
Not allowed: peft, trl, transformers, accelerate."""
import json
import os

import torch

from base import clone, load_base
from harness import evaluate_qa, text_loss
from lora import ATTENTION, add_lora, save_adapter, trainable_count
from masking import train_sft
from sft_data import clean_examples, encode_all
from trust import decontaminate, mean_std

MLP = ("fc1", "fc2")
DEFAULTS = dict(method="lora", steps=150, lr=3e-3, r=8, alpha=16.0, targets=ATTENTION + MLP, batch_size=16,
                seeds=[0], base_path="base/checkpoint.pt", orig_text="data/holmes_val.txt", orig_tokens=3000)


def run_capstone(train_rows, eval_rows, out_dir, config=None, limitations=""):
    """Fine-tune the base model on question-answer rows and evaluate it against the base. train_rows and eval_rows are
    lists of {"question", "answer"}; `config` overrides DEFAULTS (method "lora" or "full"). Steps, in this order:

      1. base, tok = load_base(cfg["base_path"]).
      2. train = clean_examples(train_rows) (lesson 05); ValueError when nothing is left.
      3. Contamination: train, removed = decontaminate(train, eval_rows, n=8, field="question") (lesson 16). The evaluation
         questions must never reach training.
      4. items, too_long = encode_all(tok, train, base.block_size).
      5. The baseline: evaluate_qa(base, tok, eval_rows) and, when cfg["orig_text"] exists, the loss of the base on its first
         cfg["orig_tokens"] tokens (text_loss on tok.encode of the file): the "original" loss that shows forgetting.
      6. For every seed in cfg["seeds"]: m = clone(base); for method "lora" add_lora(m, cfg["targets"], cfg["r"], cfg["alpha"],
         seed) ; train_sft(m, items, cfg["steps"], cfg["lr"], batch_size=cfg["batch_size"], seed=seed) (call it by this name:
         the tests wrap it); evaluate_qa on eval_rows and the original loss again. Method "full" trains every weight (no
         adapters); an unknown method is a ValueError. The FIRST seed's model is saved: for "lora" with save_adapter to
         out_dir/adapter.pt; for "full" as out_dir/tuned.pt, the base checkpoint dict with "model_state" replaced by the
         tuned weights (torch.load the base_path file, replace, torch.save).
      7. Write out_dir/results.json (json, sorted keys, indent 2) and out_dir/MODEL_CARD.md (make_model_card), and return the
         results dict:
           {"method", "n_train" (examples trained on), "n_eval", "n_removed" (training rows removed as contaminated),
            "n_too_long", "trainable" (trainable parameters: trainable_count of the lora model, or all parameters for "full"),
            "config": the cfg used with "targets" as a list,
            "base":  {"format", "exact", "orig_loss"},            (orig_loss None when there is no original text)
            "tuned": {"format", "exact", "orig_loss"},            (means over the seeds)
            "exact_per_seed": [exact of every seed], "exact_std": sample std of those (mean_std; 0.0 for one seed)}"""
    # TODO
    raise NotImplementedError


def make_model_card(results, source, limitations):
    """Markdown with exactly these headings, in this order:
         # Model card
         ## Task              what was learned and from how many examples (n_train, n_eval)
         ## Base model        the text of `source` (base/SOURCE.txt) stripped
         ## Data              n_train, n_removed (contaminated), n_too_long, n_eval
         ## Method            the method, steps, learning rate, batch size, seeds, and for LoRA the rank, alpha, targets and the number of trainable parameters
         ## Results           a table of base versus tuned: format, exact match and original-text loss, each with 3 decimals, plus exact_std over the seeds
         ## Limitations       the text `limitations` you pass in, written by you (at least 20 words: what it cannot do, where the data is thin)
       Every number must appear as plain digits, formatted like "%.3f" for the metrics and as integers for the counts."""
    # TODO
    raise NotImplementedError
