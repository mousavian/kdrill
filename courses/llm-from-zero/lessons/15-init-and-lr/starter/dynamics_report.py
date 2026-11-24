"""Initialisation and learning-rate diagnostics on real data.  make py F=dynamics_report.py"""
import numpy as np

import dynamics, mlp_lm

tr = open("data/train.txt", encoding="utf-8").read()[:150000]
chars = sorted(set(tr))
ids = np.array([chars.index(c) for c in tr])
V = len(chars)
X, Y = mlp_lm.make_dataset(ids, 3)
print("ln V = %.3f" % np.log(V))
for name, kw in [("kaiming, small W2", {}), ("W2 scale 1.0", {"w2_scale": 1.0}),
                 ("W1 scale 0.05", {"w1_scale": 0.05}), ("W1 scale 3.0", {"w1_scale": 3.0})]:
    p = dynamics.make_params(V, 3, 8, 64, **kw)
    loss, cache = mlp_lm.forward(p, X[:2000], Y[:2000])
    s = dynamics.hidden_stats(p, X[:2000])
    print("%-20s first loss %7.3f  h.std %.3f  saturated %.2f" % (name, loss, s["std"], s["saturated"]))
p = dynamics.make_params(V, 3, 8, 64)
rows = dynamics.lr_range_test(p, X, Y)
print("range test:", ["%.3g:%.2f" % r for r in rows[::6]])
lr = dynamics.suggest_lr(rows)
print("suggested lr", lr)
mlp_lm.train(p, X, Y, steps=2000, lr=lr, batch_size=64)
loss, cache = mlp_lm.forward(p, X[:4000], Y[:4000])
print("update ratios:", {k: round(v, 2) for k, v in dynamics.update_ratio(p, mlp_lm.backward(p, cache), lr).items()})
