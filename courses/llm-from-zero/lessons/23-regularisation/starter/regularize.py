"""Lesson 23 - regularisation (PyTorch). Uses get_batch/evaluate from your loop.py (lesson 18).
Your gpt.py from lesson 21 already has dropout."""
import copy

import torch

from loop import evaluate, get_batch


def configure_optimizer(model, weight_decay, lr, betas=(0.9, 0.95)):
    """torch.optim.AdamW with two parameter groups, in this order:
      1. decay group: parameters with ndim >= 2 (weight matrices and embeddings), weight_decay=weight_decay
      2. no-decay group: parameters with ndim < 2 (biases, LayerNorm scales and shifts), weight_decay=0.0
    Every parameter appears exactly once, even if the model shares one between two modules
    (tied embedding / output weights); skip parameters with requires_grad False.
    Return the optimizer."""
    # TODO
    raise NotImplementedError


class EarlyStopping:
    """Stop when validation loss has not improved for `patience` evaluations in a row.

    Attributes: best (float, starts at inf), best_step (None at first), bad_count (0), should_stop (False).
    update(val_loss, step) -> bool: an IMPROVEMENT is val_loss < best - min_delta. On improvement set
    best, best_step = step, bad_count = 0 and return True; otherwise bad_count += 1, set
    should_stop = (bad_count >= patience) and return False."""

    def __init__(self, patience, min_delta=0.0):
        self.patience, self.min_delta = patience, min_delta
        # TODO
        raise NotImplementedError

    def update(self, val_loss, step):
        # TODO
        raise NotImplementedError


def train_with_early_stopping(model, train_data, val_data, block_size, batch_size, max_steps, lr,
                              weight_decay, eval_every, eval_iters, patience, seed=0):
    """Train with configure_optimizer and stop on validation loss.

    - data_generator = torch.Generator().manual_seed(seed) for training batches only.
    - Each step: model.train(), forward on a batch, zero_grad(set_to_none=True), backward, optimizer step.
    - After every update with (step + 1) % eval_every == 0: val = evaluate(model, val_data, ..., eval_iters,
      torch.Generator().manual_seed(1234)) and train_loss likewise on train_data. Append
      (step + 1, train_loss, val) to history; call EarlyStopping.update(val, step + 1). When it reports an
      improvement, keep a deep copy of model.state_dict() (copy.deepcopy). Stop the loop when should_stop.
    - At the end load the best saved weights back into the model (if any evaluation happened).
    Return {"best_val": float, "best_step": int, "stopped_at": number of updates done, "history": [...]}."""
    # TODO
    raise NotImplementedError
