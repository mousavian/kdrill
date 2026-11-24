"""Lesson 23 - reference solution."""
import copy

import torch

from loop import evaluate, get_batch


def configure_optimizer(model, weight_decay, lr, betas=(0.9, 0.95)):
    seen, decay, no_decay = set(), [], []
    for p in model.parameters():
        if not p.requires_grad or id(p) in seen:
            continue
        seen.add(id(p))
        (decay if p.ndim >= 2 else no_decay).append(p)
    groups = [{"params": decay, "weight_decay": weight_decay}, {"params": no_decay, "weight_decay": 0.0}]
    return torch.optim.AdamW(groups, lr=lr, betas=betas)


class EarlyStopping:
    def __init__(self, patience, min_delta=0.0):
        self.patience, self.min_delta = patience, min_delta
        self.best, self.best_step, self.bad_count, self.should_stop = float("inf"), None, 0, False

    def update(self, val_loss, step):
        if val_loss < self.best - self.min_delta:
            self.best, self.best_step, self.bad_count = val_loss, step, 0
            return True
        self.bad_count += 1
        self.should_stop = self.bad_count >= self.patience
        return False


def train_with_early_stopping(model, train_data, val_data, block_size, batch_size, max_steps, lr,
                              weight_decay, eval_every, eval_iters, patience, seed=0):
    opt = configure_optimizer(model, weight_decay, lr)
    g = torch.Generator().manual_seed(seed)
    stopper = EarlyStopping(patience)
    best_state, history, done = None, [], 0
    for step in range(max_steps):
        x, y = get_batch(train_data, block_size, batch_size, g)
        model.train()
        _, loss = model(x, y)
        opt.zero_grad(set_to_none=True)
        loss.backward()
        opt.step()
        done = step + 1
        if done % eval_every == 0:
            tl = evaluate(model, train_data, block_size, batch_size, eval_iters, torch.Generator().manual_seed(1234))
            vl = evaluate(model, val_data, block_size, batch_size, eval_iters, torch.Generator().manual_seed(1234))
            history.append((done, tl, vl))
            if stopper.update(vl, done):
                best_state = copy.deepcopy(model.state_dict())
            if stopper.should_stop:
                break
    if best_state is not None:
        model.load_state_dict(best_state)
    return {"best_val": stopper.best, "best_step": stopper.best_step, "stopped_at": done, "history": history}
