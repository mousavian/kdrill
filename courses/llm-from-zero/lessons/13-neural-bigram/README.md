# 13 - A neural bigram

## Concept

Lesson 10 built a bigram model by counting. Here you build the *same* model with the tools
of deep learning, and discover it converges to the same table. Everything else in this
course is this recipe with a bigger function in the middle.

The recipe has five parts:

1. **Parameters**: one matrix `W` of shape `V x V`. Row `x` holds the **logits** (raw scores)
   for the token that follows `x`. (Multiplying a one-hot vector by `W` is exactly "take row
   `x`"; indexing is the fast way.)
2. **Softmax** turns logits into probabilities: `p_j = e^{z_j} / sum_k e^{z_k}`. Subtract the
   row maximum first, or large logits overflow.
3. **Loss**: cross-entropy, `-log p[y]`, averaged over a batch (lesson 11). Computed as
   `logsumexp(z) - z[y]` it stays finite for any logits.
4. **Gradient**, by hand. For one sample, `d loss / d logits = p - onehot(y)`: the model is
   pushed to raise the true token's logit and lower the others in proportion to how likely it
   thought they were. The mean over `n` samples divides by `n`, and row `x` of `W` receives the
   gradients of every sample whose input was `x` (repeated rows must *accumulate*: `np.add.at`).
5. **Gradient descent**: `W -= lr * dW`, repeated.

Why does it converge to the counting table? The optimum of the cross-entropy over a free
table is the empirical conditional distribution, which is exactly counts divided by row sums.
The network has no more parameters than the table; gradient descent just finds it slowly.
That equality is also your best test: the optimiser is only as trustworthy as your gradient.

Always **check the gradient numerically** against finite differences of the forward pass
before training. A wrong gradient does not crash; it just trains badly, and you will blame the
learning rate.

## The situation

`nbigram.py` has the functions with docstrings that define shapes and edge cases. The test
data is a generated Markov chain whose true table is known, and the real characters.

## Your task

Implement `make_xy`, `init_weights`, `softmax`, `forward`, `backward`, `train`,
`probs_from_weights`, `mean_nll`. numpy only. Verify checks softmax and loss stability,
`backward` against finite differences (with repeated inputs), that `train` lowers the loss every
step and ends at the counting model's probabilities and loss, and a run on real text
(`np.add.at` is slow on big arrays, so it uses a small slice).

## Useful commands

- `kdrill py`; use `kdrill hint` for the gradient shapes.
- `np.add.at(dW, X, dlogits)` adds row `i` of `dlogits` to row `X[i]` of `dW`.

## On a real project

You will never write this backward pass again: frameworks do it. You will, constantly, decide
whether a loss curve looks right, and knowing what `p - onehot` does helps.

## Read more

- Softmax and cross-entropy gradient: https://eli.thegreenplace.net/2016/the-softmax-function-and-its-derivative/
- The log-sum-exp trick: https://gregorygundersen.com/blog/2020/02/09/log-sum-exp/
- CS231n, optimization and backprop notes: https://cs231n.github.io/optimization-2/
