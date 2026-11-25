"""Lesson 06 - reference solution."""
import torch
import torch.nn.functional as F


def make_batch(items, pad_id=0):
    L = max(len(ids) for ids, _ in items) - 1
    x = torch.full((len(items), L), pad_id, dtype=torch.long)
    y = torch.full((len(items), L), pad_id, dtype=torch.long)
    mask = torch.zeros(len(items), L)
    for r, (ids, plen) in enumerate(items):
        n = len(ids) - 1
        t = torch.tensor(ids, dtype=torch.long)
        x[r, :n] = t[:-1]
        y[r, :n] = t[1:]
        mask[r, plen - 1:n] = 1.0
    return x, y, mask


def masked_loss(logits, targets, mask):
    if float(mask.sum()) == 0:
        raise ValueError("the mask selects no position")
    nll = F.cross_entropy(logits.reshape(-1, logits.shape[-1]), targets.reshape(-1), reduction="none").reshape(targets.shape)
    return (nll * mask).sum() / mask.sum()


def train_sft(model, items, steps, lr, batch_size=16, seed=0, pad_id=0, weight_decay=0.0):
    g = torch.Generator().manual_seed(seed)
    params = [p for p in model.parameters() if p.requires_grad]
    opt = torch.optim.AdamW(params, lr=lr, betas=(0.9, 0.95), weight_decay=weight_decay)
    was = model.training
    model.train()
    losses = []
    for _ in range(steps):
        ix = torch.randint(0, len(items), (batch_size,), generator=g).tolist()
        x, y, mask = make_batch([items[i] for i in ix], pad_id)
        loss = masked_loss(model(x)[0], y, mask)
        opt.zero_grad(set_to_none=True)
        loss.backward()
        opt.step()
        losses.append(float(loss.item()))
    model.train(was)
    return losses
