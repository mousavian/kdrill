# 12 - Autograd from scratch

## Concept

Training a model means nudging every parameter in the direction that lowers the loss, and
that direction is the **gradient**: how much the loss changes per unit change of each
parameter. For a model with millions of parameters you cannot derive that by hand for every
architecture. **Automatic differentiation** computes it mechanically.

The idea is small. Every number you compute is the result of an elementary operation (add,
multiply, `tanh`, `exp`...) whose *local* derivative you know. Record the operations as a
graph while computing the result forward. Then walk the graph **backwards** from the loss,
applying the **chain rule**: the gradient reaching a node is multiplied by the local
derivative and handed to the node's inputs. This is **reverse-mode** differentiation
(backpropagation) and it gives the gradient of one output with respect to *all* inputs in
one backward pass, which is why it suits "one loss, many parameters".

Three details are the whole difficulty:

- A value can be used **more than once** (`a * a + a`): its gradient is the *sum* of the
  contributions from every use, so each `_backward` does `+=`.
- Nodes must be processed in **reverse topological order**, so that when a node's `_backward`
  runs, all the gradient flowing into it has already arrived. A depth-first search does it, but
  write it without recursion: a long training loop builds graphs thousands of operations deep.
- **Check gradients numerically.** `(f(x + h) - f(x - h)) / 2h` for a small `h` is slow but
  nearly always right, and is how you debug any hand-written backward pass. Lessons 13 and 14 use
  the same check on matrices.

PyTorch's autograd is this idea on tensors, with fast kernels. Writing the scalar version once
means nothing in `loss.backward()` will ever look like magic again.

## The situation

`autograd.py` defines `Value` with the operations to complete; standard library only.
`neuron_demo.py` fits one neuron with your engine.

## Your task

Implement `__add__`, `__mul__`, `__pow__`, `exp`, `log`, `tanh`, `relu`, the derived
operations (`__neg__`, `__sub__`, `__truediv__`, `__rsub__`, `__rtruediv__`) and `backward`.
Verify differentiates every operation against finite differences, checks reuse and diamond
graphs, random expression graphs, a 20,000-deep chain (no recursion), repeated `backward()`
calls, a neuron that must learn, and a softmax cross-entropy whose gradient must be
`p - onehot`. `numpy` and `torch` are not allowed here.

## Useful commands

- `make py F=neuron_demo.py`
- `kdrill py`: `from autograd import Value; a = Value(2); b = a*a + a; b.backward(); a.grad`

## On a real project

You will never ship this, but you will read tracebacks like "one of the variables needed for
gradient computation has been modified by an inplace operation": that is the graph you just
built, being violated.

## Read more

- Automatic differentiation in machine learning: a survey: https://arxiv.org/abs/1502.05767
- PyTorch autograd mechanics: https://pytorch.org/docs/stable/notes/autograd.html
- Calculus on computational graphs (Olah): https://colah.github.io/posts/2015-08-Backprop/
