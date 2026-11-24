import math
import random

import pytest

from autograd import Value
from kdlib import kdtest


def test_standard_library_only():
    """the engine is plain Python: no numpy, torch, jax, tensorflow, autograd, sympy"""
    kdtest.assert_no_imports("autograd", {"numpy", "torch", "jax", "tensorflow", "autograd", "sympy", "scipy"})


def test_basic_derivatives():
    """d(a*b+c)/da = b, /db = a, /dc = 1, with values computed forward"""
    a, b, c = Value(2.0), Value(-3.0), Value(10.0)
    d = a * b + c
    assert d.data == 4.0
    d.backward()
    assert (a.grad, b.grad, c.grad) == (-3.0, 2.0, 1.0)


@pytest.mark.parametrize("name,f,x", [
    ("tanh", lambda v: v.tanh(), 0.3), ("exp", lambda v: v.exp(), 0.7), ("log", lambda v: v.log(), 1.7),
    ("pow3", lambda v: v ** 3, -1.2), ("pow_half", lambda v: v ** 0.5, 2.0), ("pow_neg", lambda v: v ** -2, 1.5),
    ("relu+", lambda v: v.relu(), 0.5), ("relu-", lambda v: v.relu(), -0.5), ("neg", lambda v: -v, 0.4),
    ("rsub", lambda v: 3 - v, 0.4), ("rdiv", lambda v: 2 / v, 0.8), ("div", lambda v: v / 4, 0.8),
    ("rmul", lambda v: 5 * v, 0.2), ("radd", lambda v: 5 + v, 0.2), ("sub", lambda v: v - 2.5, 1.0),
])
def test_each_operation_against_finite_differences(name, f, x):
    """gradient of every operation matches central finite differences"""
    v = Value(x)
    out = f(v)
    out.backward()
    h = 1e-6
    num = (f(Value(x + h)).data - f(Value(x - h)).data) / (2 * h)
    assert v.grad == pytest.approx(num, rel=1e-5, abs=1e-7), name


def test_value_used_more_than_once():
    """a value used several times accumulates the gradient of every use (a*a + a, diamond graphs)"""
    a = Value(3.0)
    y = a * a + a          # dy/da = 2a + 1 = 7
    y.backward()
    assert a.grad == 7.0
    x = Value(2.0)
    p, q = x * 3, x ** 2   # diamond: x -> p, x -> q -> r
    r = p * q              # 3x * x^2 = 3x^3, d/dx = 9x^2 = 36
    r.backward()
    assert x.grad == pytest.approx(36.0)


def test_random_expression_graphs():
    """random expression graphs agree with finite differences for every leaf"""
    rnd = random.Random(1)
    ops = ["add", "mul", "sub", "tanh", "exp", "div", "pow"]
    for trial in range(25):
        recipe = [(rnd.choice(ops), rnd.random()) for _ in range(12)]
        xs = [rnd.uniform(0.3, 1.2) for _ in range(4)]

        def build(vals):
            pool = list(vals)
            for i, (op, r) in enumerate(recipe):
                a, b = pool[i % len(pool)], pool[(i * 7 + 3) % len(pool)]
                if op == "add": n = a + b
                elif op == "mul": n = a * b * 0.7
                elif op == "sub": n = a - b
                elif op == "tanh": n = a.tanh()
                elif op == "exp": n = (a * 0.3).exp()
                elif op == "div": n = a / (b * b + 1.5)
                else: n = (a * a + 0.5) ** 0.5
                pool.append(n)
            return pool[-1] + pool[-2] * 0.5
        leaves = [Value(x) for x in xs]
        out = build(leaves)
        out.backward()
        for i in range(4):
            h = 1e-6
            up = build([Value(x + (h if j == i else 0)) for j, x in enumerate(xs)]).data
            dn = build([Value(x - (h if j == i else 0)) for j, x in enumerate(xs)]).data
            assert leaves[i].grad == pytest.approx((up - dn) / (2 * h), rel=1e-4, abs=1e-6), (trial, i)


def test_deep_graph_does_not_hit_the_recursion_limit():
    """a chain of 20000 additions backpropagates without recursion"""
    a = Value(1.0)
    s = a
    for _ in range(20000):
        s = s + a
    s.backward()
    assert s.data == 20001.0 and a.grad == 20001.0


def test_backward_recomputes():
    """calling backward twice gives the same gradients (not doubled); gradients start from the root's 1"""
    a, b = Value(2.0), Value(5.0)
    y = a * b
    y.backward(); y.backward()
    assert (a.grad, b.grad, y.grad) == (5.0, 2.0, 1.0)
    z = y * y            # new root over the same graph: old grads must not linger
    z.backward()
    assert a.grad == pytest.approx(2 * 10 * 5)


def test_train_a_neuron():
    """gradient descent with your gradients fits y = tanh(2x - 1): the loss falls below 1e-3"""
    random.seed(0)
    xs = [-1.0, -0.5, 0.0, 0.5, 1.0]
    ys = [math.tanh(2 * x - 1) for x in xs]
    w, b = Value(0.3), Value(0.0)
    first = None
    for step in range(150):
        loss = sum(((w * x + b).tanh() - y) ** 2 for x, y in zip(xs, ys)) * (1 / len(xs))
        loss.backward()
        first = loss.data if first is None else first
        w.data -= 0.5 * w.grad
        b.data -= 0.5 * b.grad
    assert loss.data < 1e-3 < first


def test_log_softmax_cross_entropy_matches_math():
    """a small softmax cross-entropy built from Values gives the right loss and the textbook gradient p - onehot"""
    logits = [Value(x) for x in (1.0, 2.0, 0.5)]
    m = sum(l.exp() for l in logits)
    probs = [l.exp() / m for l in logits]
    loss = -(probs[1].log())
    loss.backward()
    z = sum(math.exp(x) for x in (1.0, 2.0, 0.5))
    p = [math.exp(x) / z for x in (1.0, 2.0, 0.5)]
    assert loss.data == pytest.approx(-math.log(p[1]))
    assert [l.grad for l in logits] == pytest.approx([p[0], p[1] - 1, p[2]], abs=1e-9)
