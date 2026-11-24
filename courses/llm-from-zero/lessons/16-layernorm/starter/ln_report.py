"""Signal size through a deep tanh stack with and without layer norm.  make py F=ln_report.py"""
from layernorm import deep_pre_activation_stds

for scale in (0.02, 0.1, 0.3, 1.0):
    plain = deep_pre_activation_stds(20, 128, scale, use_layernorm=False)
    normed = deep_pre_activation_stds(20, 128, scale, use_layernorm=True)
    print("weight scale %-5g plain: layer 1 %.4f ... layer 20 %.2e | with layernorm: layer 1 %.3f ... layer 20 %.3f"
          % (scale, plain[0], plain[-1], normed[0], normed[-1]))
