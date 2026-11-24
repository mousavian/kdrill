"""Lesson 14 - an MLP language model with hand-written backprop. numpy only (no torch).

Model (Bengio et al. 2003, in miniature), for a context of `context` previous tokens:
    emb    = C[X]                       (N, context, d_emb)   embedding lookup
    flat   = emb.reshape(N, context * d_emb)
    h      = tanh(flat @ W1 + b1)       (N, hidden)
    logits = h @ W2 + b2                (N, V)
    loss   = mean over N of -log softmax(logits)[y]
"""
import numpy as np


def init_params(V, context, d_emb, hidden, seed=0):
    """(given) The parameters, a dict of float64 arrays."""
    rng = np.random.default_rng(seed)
    fan_in = context * d_emb
    return {
        "C": rng.normal(size=(V, d_emb)),
        "W1": rng.normal(size=(fan_in, hidden)) / np.sqrt(fan_in),
        "b1": np.zeros(hidden),
        "W2": rng.normal(size=(hidden, V)) * 0.05,
        "b2": np.zeros(V),
    }


def make_dataset(ids, context):
    """(given) X[i] = ids[i : i + context], Y[i] = ids[i + context]; X is (N, context) int64."""
    ids = np.asarray(ids, dtype=np.int64)
    n = len(ids) - context
    X = np.stack([ids[j:j + n] for j in range(context)], axis=1)
    return X, ids[context:]


def forward(params, X, Y):
    """Return (loss, cache). `loss` is a float; `cache` holds whatever backward needs
    (inputs, flat embeddings, hidden activations, probabilities). Use log-sum-exp for the
    loss so large logits do not overflow."""
    # TODO
    raise NotImplementedError


def backward(params, cache):
    """Return grads: a dict with the same keys and shapes as params, the gradient of the
    MEAN loss wrt every parameter. Work backwards through every step of forward:
    softmax + cross-entropy, the second linear layer, tanh (derivative 1 - h**2), the first
    linear layer, the reshape, and the embedding lookup (several positions can use the same
    token: accumulate with np.add.at). Do not modify params or cache."""
    # TODO
    raise NotImplementedError


def train(params, X, Y, steps, lr, batch_size=32, seed=0):
    """Minibatch SGD, modifying `params` in place. For each step draw `batch_size` row
    indices with rng.integers(0, N, batch_size) (rng = np.random.default_rng(seed)), compute
    loss and grads on that batch and do p -= lr * grad for every parameter.
    Return the list of minibatch losses."""
    # TODO
    raise NotImplementedError


def evaluate_loss(params, X, Y, batch=4096):
    """Mean loss over ALL rows of (X, Y), processed in chunks of `batch` rows so memory
    stays small. (The mean over everything, not the mean of chunk means of unequal sizes.)"""
    # TODO
    raise NotImplementedError


def next_probs(params, window):
    """Probability distribution (shape (V,)) of the token after `window`, a sequence of
    exactly `context` ids."""
    # TODO
    raise NotImplementedError


def sample(params, prompt, n, seed=0):
    """Generate n ids autoregressively. `prompt` has at least `context` ids; each new id is
    drawn (rng = np.random.default_rng(seed)) from next_probs of the last `context` ids seen.
    Return the n new ids as a list of Python ints (the prompt is not included)."""
    # TODO
    raise NotImplementedError
