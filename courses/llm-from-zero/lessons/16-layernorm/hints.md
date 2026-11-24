Forward: `mean = x.mean(axis=1, keepdims=True)`, `var = x.var(axis=1, keepdims=True)`, `rstd = 1 / np.sqrt(var + eps)`, `xhat = (x - mean) * rstd`, `out = gamma * xhat + beta`. Cache `xhat`, `rstd` and `gamma`.
---
Backward: `dbeta = dout.sum(axis=0)`, `dgamma = (dout * xhat).sum(axis=0)`, `dxhat = dout * gamma`, and `dx = rstd * (dxhat - dxhat.mean(axis=1, keepdims=True) - xhat * (dxhat * xhat).mean(axis=1, keepdims=True))`. If the check fails, test `dgamma` and `dbeta` first; they are easy. Then `dx`: the two `mean` terms are exactly what is missing from the naive `dxhat * rstd`.
---
`deep_pre_activation_stds`: draw `h = rng.normal(size=(n, width))` first, then for each layer `W = rng.normal(size=(width, width)) * weight_scale`, `z = h @ W`, optionally `z, _ = layernorm_forward(z, np.ones(width), np.zeros(width))`, record `float(z.std())`, set `h = np.tanh(z)`.
