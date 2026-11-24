`to_torch`: `torch.tensor(np.array(v, dtype=np.float64), requires_grad=True)` makes a float64 copy that is tracked. `loss_fn`: `tp["C"][X]` indexes with a LongTensor, `.reshape(N, -1)` flattens the context, then `torch.tanh(flat @ W1 + b1)`, `h @ W2 + b2`, and `F.cross_entropy(logits, Y)`.
---
`torch_grads`: first `p.grad = None` for every tensor, then `loss_fn(...).backward()`, then collect `p.grad.detach().numpy().copy()`. `sgd_step`: `with torch.no_grad(): p -= lr * p.grad` for each tensor (an in-place update keeps it a leaf), then set `p.grad = None`.
---
`train_torch`: `Xt = torch.from_numpy(X)`; `g = torch.Generator().manual_seed(seed)`; each step `idx = torch.randint(0, N, (batch_size,), generator=g)`, `loss = loss_fn(tp, Xt[idx], Yt[idx])`, `loss.backward()`, record `loss.item()`, `sgd_step(tp, lr)`. Index tensors must be int64: `np.asarray(X)` from `make_dataset` already is.
