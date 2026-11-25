"""Train the reference SFT model (pylib/kdlib/data/ref_sft.pt): the base model fine-tuned on question-answer examples
where half of the answers are terse and half are chatty (the starting point of the DPO lessons).

    docker run ... python3 make_sft.py OUT_DIR       (the course container with /kdlib mounted)
Same recipe as the reference solution of lesson 06: loss on the answer tokens, 400 steps, lr 2e-3, seed 0.
"""
import os
import sys

import torch

from kdlib import refimpl as I
from kdlib import tasks as T

out = sys.argv[1]
torch.set_num_threads(2)
m, tok = I.ref_base()
tr, _ = T.train_eval_qa()
mixed = T.make_mixed_sft(tr, seed=5)
items = [I.encode_qa(tok, r["question"], r["answer"]) for r in mixed]
torch.manual_seed(0)
I.sft_train(m, items, 400, 2e-3, seed=0, pad=0)
ck = torch.load(os.path.join(T.DATA, "ref_base.pt"), weights_only=False)
ck["model_state"] = m.state_dict()
ck["data_card"] = "reference SFT model: base + 400 SFT steps on half-terse, half-chatty answers"
os.makedirs(out, exist_ok=True)
torch.save(ck, os.path.join(out, "ref_sft.pt"))
print("chatty rate", I.chatty_rate(m, tok, T.train_eval_qa()[1], 60))
