"""The classic sanity check: a model that cannot memorise ONE batch is broken.  make py F=overfit_one_batch.py"""
import torch

from gpt import GPT, gpt_param_count

torch.manual_seed(0)
V, T = 30, 16
model = GPT(V, T, n_layer=2, n_head=2, n_embd=32)
print("parameters:", model.num_params(), "formula:", gpt_param_count(V, T, 2, 32))
x = torch.randint(0, V, (4, T))
y = torch.randint(0, V, (4, T))
opt = torch.optim.AdamW(model.parameters(), lr=3e-3)
for step in range(301):
    _, loss = model(x, y)
    if step % 50 == 0:
        print("step %3d loss %.4f   (ln V = %.3f)" % (step, loss.item(), torch.log(torch.tensor(float(V))).item()))
    opt.zero_grad()
    loss.backward()
    opt.step()
