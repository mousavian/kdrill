# 14 - An MLP language model with manual backprop

## Concept

A bigram sees one character of context, so it cannot know that `th` is usually followed by
`e`. The natural fix is to look at the previous *several* tokens, but a table indexed by every
possible context grows as `V^context`: hopeless. Bengio et al. (2003) solved it with two ideas
that are still the core of every language model.

1. **Embeddings.** Give each token a learned vector of `d` numbers. Tokens used in similar ways
   end up with similar vectors, so what the model learns about `a` helps with `e` and `i`. The
   lookup `C[x]` is a table of parameters, trained like any other.
2. **A shared function of the context.** Concatenate the embeddings of the last `context`
   tokens, pass them through a hidden layer with a non-linearity (`tanh`), and produce logits for
   the next token. The number of parameters grows with `context * d`, not with `V^context`.

Training is the same as lesson 13: cross-entropy loss, gradient, step. The new work is the
**backward pass through several layers**. Do it the way you did in lesson 12 but on whole
arrays: start from `probs - onehot` at the logits, and at each layer (1) the gradient of the
weights is the layer's input transposed times the incoming gradient, (2) the gradient passed on
is the incoming gradient times the weights transposed, (3) through `tanh` multiply by
`1 - h^2`. The embedding lookup is the last step: the gradient of each looked-up row goes back
to that row of `C`, and a token that appears several times accumulates (`np.add.at`).

Use **minibatches**: gradients from 32 to 64 random samples are a noisy but cheap estimate of
the full gradient, and many noisy steps beat few exact ones.

And always run a numeric **gradient check** on every parameter: a bug in one of five gradients
is invisible in the loss curve for a long time.

## The situation

`mlp_lm.py` gives the model definition, `init_params`, `make_dataset` and the function
signatures. All shapes are in the docstrings.

## Your task

Implement `forward`, `backward`, `train`, `evaluate_loss`, `next_probs` and `sample`. numpy only.
Verify compares `forward` with a reference, checks `backward` against finite differences for each
of `C, W1, b1, W2, b2` (batches with repeated tokens, non-zero biases), the stability of the
loss, seeded determinism, chunked evaluation, learning a pattern, and that on real text the
model reaches a clearly lower validation loss than the best bigram (about 2.4 nats at the
character level; yours should be near 2.0).

## Useful commands

- `kdrill hint` for the backward-pass shapes.
- On real data, a full run is a few seconds: build `X, Y = make_dataset(ids, 3)` and call `train`.

## On a real project

The transformer replaces "concatenate and one hidden layer" with attention, but keeps embeddings,
a stack of layers and cross-entropy. Everything you wrote here reappears with PyTorch doing the
backward pass.

## Read more

- A Neural Probabilistic Language Model (Bengio et al., 2003): https://www.jmlr.org/papers/v3/bengio03a.html
- CS231n, backprop for matrix operations: https://cs231n.github.io/optimization-2/#mat
- Efficient Backprop (LeCun et al.): http://yann.lecun.com/exdb/publis/pdf/lecun-98b.pdf
