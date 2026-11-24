# 17 - From numpy to PyTorch

## Concept

Parts A to C were about understanding. From here on you use **PyTorch**, which does three
things for you: it stores numbers in **tensors** (like numpy arrays, but able to live on a GPU
and to remember how they were computed), it runs the **backward pass** automatically (the
engine you wrote in lesson 12, on whole arrays with fast kernels), and it provides the building
blocks (layers, optimisers) you will use for the transformer.

The mechanics are small:

- A tensor created with `requires_grad=True` is tracked. Every operation on it builds a graph;
  the result has a `grad_fn`. `loss.backward()` walks the graph and fills `p.grad` for every
  tracked leaf. Gradients **accumulate** across calls, so clear them (`p.grad = None`, or
  `optimizer.zero_grad()`) before each backward pass: forgetting this is the classic bug.
- Updating parameters is not itself part of the graph: do it under `torch.no_grad()`.
- Index tensors must be `torch.long`; model tensors are `float32` by default. Here you use
  `float64` so that autograd can be compared digit for digit with numpy.
- `F.cross_entropy(logits, targets)` takes raw logits and class indices and uses the stable
  log-sum-exp internally, exactly the loss you wrote by hand.

The best way to trust autograd is to **make it agree with what you derived**. That check is the
point of this lesson: the gradients of the MLP you backpropagated by hand in lesson 14 must come
out of `loss.backward()` identical to about 12 digits. From now on you will not write another
backward pass; knowing it is right, and what it does, is what you keep.

## The situation

`torch_port.py` has the functions. `port_check.py` compares autograd with your own
`mlp_lm.backward`. (Do not import `mlp_lm` inside `torch_port.py`: verify rejects it.)

## Your task

Implement `to_torch`, `loss_fn`, `torch_grads`, `max_abs_diff`, `sgd_step` and `train_torch`.
Verify checks dtypes and copies, the loss against an independent numpy reference, the autograd
gradients against hand-derived ones (and against your lesson 14 `backward` if present), that
repeated calls do not accumulate gradients, the in-place SGD step, and a seeded training run.

Then `make py F=port_check.py` and read the difference (it should be around 1e-17).

## Useful commands

- `kdrill py`: `import torch; x = torch.tensor(2.0, requires_grad=True); (x**3).backward(); x.grad`
- `kdrill hint`; `kdrill solution`.

## On a real project

Use `torch.optim` (next lesson) instead of hand-written SGD, `float32` or `bfloat16` instead of
`float64`, and `torch.autograd.gradcheck` for numeric checks of custom functions.

## Read more

- PyTorch autograd tutorial: https://pytorch.org/tutorials/beginner/blitz/autograd_tutorial.html
- `torch.nn.functional.cross_entropy`: https://pytorch.org/docs/stable/generated/torch.nn.functional.cross_entropy.html
- PyTorch tensors: https://pytorch.org/docs/stable/tensors.html
