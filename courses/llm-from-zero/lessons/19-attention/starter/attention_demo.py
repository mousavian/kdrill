"""Look at what one head attends to.  make py F=attention_demo.py"""
import torch

from attention import Head

torch.manual_seed(0)
h = Head(n_embd=16, head_size=8, block_size=6)
x = torch.randn(1, 6, 16)
out = h(x)
torch.set_printoptions(precision=2, sci_mode=False)
print("output shape", tuple(out.shape))
print("attention weights (row t = how position t spreads its attention over positions 0..t):")
print(h.att[0])
