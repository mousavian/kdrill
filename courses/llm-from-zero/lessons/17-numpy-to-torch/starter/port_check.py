"""Compare autograd with your hand-written backward pass from lesson 14.  make py F=port_check.py"""
import numpy as np
import torch

import mlp_lm
import torch_port as tp

p = mlp_lm.init_params(12, 3, 4, 8, seed=0)
rng = np.random.default_rng(0)
X, Y = rng.integers(0, 12, (40, 3)), rng.integers(0, 12, 40)
loss, cache = mlp_lm.forward(p, X, Y)
hand = mlp_lm.backward(p, cache)
t = tp.to_torch(p)
auto = tp.torch_grads(t, torch.from_numpy(X), torch.from_numpy(Y))
print("numpy loss %.12f  torch loss %.12f" % (loss, tp.loss_fn(t, torch.from_numpy(X), torch.from_numpy(Y)).item()))
print("largest difference between hand-written and autograd gradients: %.2e" % tp.max_abs_diff(hand, auto))
