"""Lesson 18 - reference solution."""
import torch
import torch.nn as nn
import torch.nn.functional as F


class BigramLM(nn.Module):
    def __init__(self, vocab_size):
        super().__init__()
        self.table = nn.Embedding(vocab_size, vocab_size)

    def forward(self, idx, targets=None):
        logits = self.table(idx)
        loss = None
        if targets is not None:
            loss = F.cross_entropy(logits.reshape(-1, logits.shape[-1]), targets.reshape(-1))
        return logits, loss


def get_batch(data, block_size, batch_size, generator=None):
    if len(data) <= block_size:
        raise ValueError("data is shorter than one block")
    ix = torch.randint(0, len(data) - block_size, (batch_size,), generator=generator)
    x = torch.stack([data[i:i + block_size] for i in ix.tolist()])
    y = torch.stack([data[i + 1:i + block_size + 1] for i in ix.tolist()])
    return x, y


@torch.no_grad()
def evaluate(model, data, block_size, batch_size, iters, generator=None):
    was_training = model.training
    model.eval()
    total = 0.0
    for _ in range(iters):
        x, y = get_batch(data, block_size, batch_size, generator)
        _, loss = model(x, y)
        total += loss.item()
    model.train(was_training)
    return total / iters


def train(model, train_data, val_data, block_size, batch_size, steps, lr, eval_every=100,
          eval_iters=20, seed=0, weight_decay=0.0, log=print):
    opt = torch.optim.AdamW(model.parameters(), lr=lr, weight_decay=weight_decay)
    g = torch.Generator().manual_seed(seed)
    history = []
    for step in range(steps):
        if step % eval_every == 0:
            history.append(_eval_row(model, train_data, val_data, block_size, batch_size, eval_iters, step, log))
        x, y = get_batch(train_data, block_size, batch_size, g)
        model.train()
        _, loss = model(x, y)
        opt.zero_grad(set_to_none=True)
        loss.backward()
        opt.step()
    history.append(_eval_row(model, train_data, val_data, block_size, batch_size, eval_iters, steps, log))
    return history


def _eval_row(model, train_data, val_data, block_size, batch_size, iters, step, log):
    tl = evaluate(model, train_data, block_size, batch_size, iters, torch.Generator().manual_seed(1234))
    vl = evaluate(model, val_data, block_size, batch_size, iters, torch.Generator().manual_seed(1234))
    log("step %d: train loss %.4f, val loss %.4f" % (step, tl, vl))
    return {"step": step, "train_loss": tl, "val_loss": vl}
