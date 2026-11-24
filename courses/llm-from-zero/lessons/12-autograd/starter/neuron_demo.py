"""Fit y = tanh(2x - 1) with one neuron using YOUR autograd.  make py F=neuron_demo.py"""
import math
import random

from autograd import Value

random.seed(0)
xs = [-1.0, -0.5, 0.0, 0.5, 1.0]
ys = [math.tanh(2 * x - 1) for x in xs]
w, b = Value(random.uniform(-1, 1)), Value(0.0)
for step in range(100):
    loss = sum(((w * x + b).tanh() - y) ** 2 for x, y in zip(xs, ys)) * (1 / len(xs))
    loss.backward()
    w.data -= 0.5 * w.grad
    b.data -= 0.5 * b.grad
    if step % 20 == 0 or step == 99:
        print("step %3d loss %.5f w %.3f b %.3f" % (step, loss.data, w.data, b.data))
