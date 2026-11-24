# Solution notes

- `torch.tensor(..., requires_grad=True)` on a float64 numpy copy gives exactly the lesson-14 parameters as tracked leaves. In-place updates (`p -= ...`) under `no_grad` keep them leaves.
- The whole backward pass you wrote by hand is `loss.backward()`. The two agree to about 1e-17 (that is float64 rounding); if yours disagree beyond 1e-10, one of them has a bug, and the hand-written one is the usual suspect.
- `p.grad = None` before each backward is what `optimizer.zero_grad()` does.
- Everything from here on will be `float32` tensors in `nn.Module`s, trained with `torch.optim`; the semantics are identical.
