"""Lesson 14 - reference solution."""
import numpy as np


def init_params(V, context, d_emb, hidden, seed=0):
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
    ids = np.asarray(ids, dtype=np.int64)
    n = len(ids) - context
    X = np.stack([ids[j:j + n] for j in range(context)], axis=1)
    return X, ids[context:]


def _logits(params, X):
    N = X.shape[0]
    flat = params["C"][X].reshape(N, -1)
    h = np.tanh(flat @ params["W1"] + params["b1"])
    return flat, h, h @ params["W2"] + params["b2"]


def forward(params, X, Y):
    flat, h, logits = _logits(params, X)
    m = logits.max(axis=1, keepdims=True)
    e = np.exp(logits - m)
    s = e.sum(axis=1, keepdims=True)
    lse = (m + np.log(s))[:, 0]
    loss = float((lse - logits[np.arange(len(Y)), Y]).mean())
    return loss, {"X": X, "Y": Y, "flat": flat, "h": h, "probs": e / s}


def backward(params, cache):
    X, Y, flat, h, probs = cache["X"], cache["Y"], cache["flat"], cache["h"], cache["probs"]
    N, context = X.shape
    d_emb = params["C"].shape[1]
    dlogits = probs.copy()
    dlogits[np.arange(N), Y] -= 1.0
    dlogits /= N
    dW2 = h.T @ dlogits
    db2 = dlogits.sum(axis=0)
    dhpre = (dlogits @ params["W2"].T) * (1.0 - h * h)
    dW1 = flat.T @ dhpre
    db1 = dhpre.sum(axis=0)
    demb = (dhpre @ params["W1"].T).reshape(N, context, d_emb)
    dC = np.zeros_like(params["C"])
    np.add.at(dC, X, demb)
    return {"C": dC, "W1": dW1, "b1": db1, "W2": dW2, "b2": db2}


def train(params, X, Y, steps, lr, batch_size=32, seed=0):
    rng = np.random.default_rng(seed)
    losses = []
    for _ in range(steps):
        idx = rng.integers(0, X.shape[0], batch_size)
        loss, cache = forward(params, X[idx], Y[idx])
        grads = backward(params, cache)
        for k in params:
            params[k] -= lr * grads[k]
        losses.append(loss)
    return losses


def evaluate_loss(params, X, Y, batch=4096):
    total = 0.0
    for i in range(0, X.shape[0], batch):
        xb, yb = X[i:i + batch], Y[i:i + batch]
        total += forward(params, xb, yb)[0] * len(yb)
    return total / X.shape[0]


def next_probs(params, window):
    _, _, logits = _logits(params, np.asarray(window, dtype=np.int64)[None, :])
    z = logits[0] - logits[0].max()
    p = np.exp(z)
    return p / p.sum()


def sample(params, prompt, n, seed=0):
    context = params["W1"].shape[0] // params["C"].shape[1]
    rng = np.random.default_rng(seed)
    seen = [int(i) for i in prompt]
    out = []
    for _ in range(n):
        p = next_probs(params, seen[-context:])
        nxt = int(rng.choice(len(p), p=p))
        seen.append(nxt)
        out.append(nxt)
    return out
