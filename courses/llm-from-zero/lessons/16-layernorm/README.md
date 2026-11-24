# 16 - Normalisation: layer norm by hand

## Concept

Careful initialisation (lesson 15) sets the scale of activations at step zero, but training
changes the weights and the scale drifts. Deep networks are fragile: multiply a signal by a
factor slightly below 1 at each of 20 layers and it vanishes; slightly above and it explodes or
saturates every `tanh`. **Normalisation layers** remove the problem at the root by re-centring
and re-scaling activations *inside* the network, at every layer, on every forward pass.

**Layer normalisation** (Ba et al., 2016) does it per sample: take the vector of `D` features
of one token, subtract its mean, divide by its standard deviation (plus a small `eps` for
safety), then apply a learned per-feature scale `gamma` and shift `beta` so the layer can still
represent anything it needs. Because it uses only the one vector, it works for any batch size
and for sequences, which is why transformers use it (batch normalisation, which averages over
the batch, is awkward for text).

Effects worth seeing with your own numbers:

- **Scale invariance.** Multiply a row by 50 and add 7: the output does not change. The weights
  feeding the layer can be badly scaled and the next layer still sees unit-size inputs.
- **Healthy signal at depth**, whatever the weight scale (the report in this lesson).
- **A more interesting gradient.** Because the output depends on the whole row (the mean and
  variance), the gradient with respect to the input is not elementwise:
  `dx = (1/sigma) * (dxhat - mean(dxhat) - xhat * mean(dxhat * xhat))`. The two subtracted terms
  are the gradient through the mean and the variance. This is the one backward pass in the
  course that is hard to guess; the numeric check is how you know you got it right.

Layer norm is cheap, adds only `2 * D` parameters and, together with residual connections
(lesson 19), makes training deep transformers routine.

## The situation

`layernorm.py` has the three functions. `ln_report.py` prints the activation scale of a
20-layer stack with and without normalisation for several weight scales.

## Your task

Implement `layernorm_forward`, `layernorm_backward` and `deep_pre_activation_stds`. numpy only.
Verify checks the output statistics, a reference computation, scale invariance, `dx`, `dgamma`
and `dbeta` against finite differences, that backward does not modify its inputs, and the
signal sizes through a deep stack.

## Useful commands

- `make py F=ln_report.py`; `kdrill hint`; `kdrill solution`.

## On a real project

Modern LLMs often use RMSNorm (no mean subtraction, no `beta`), and place the norm *before* each
sub-layer ("pre-norm", lesson 19). The idea and the gradient shape are the same.

## Read more

- Layer Normalization (Ba et al., 2016): https://arxiv.org/abs/1607.06450
- Root Mean Square Layer Normalization: https://arxiv.org/abs/1910.07467
- Deriving the gradient of batch/layer norm (Kevin Zakka): https://kevinzakka.github.io/2016/09/14/batch_normalization/
