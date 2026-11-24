"""Lesson 12 - a scalar autograd engine. Standard library only (math): no numpy, no torch."""
import math


class Value:
    """A number that remembers how it was computed.

    data   the float value
    grad   d(root)/d(this value) after root.backward()
    """

    def __init__(self, data, parents=(), op=""):
        self.data = float(data)
        self.grad = 0.0
        self._parents = tuple(parents)   # the Values this one was computed from
        self._backward = lambda: None    # pushes self.grad into the parents' grads
        self._op = op

    # --- operations. Each builds `out = Value(result, (parents...), op)` and sets
    # --- out._backward to a function that ADDS (+=) the local derivative times out.grad
    # --- to every parent's grad (+=, because a value can be used more than once).

    def __add__(self, other):
        """self + other (other may be a plain number)."""
        # TODO
        raise NotImplementedError

    def __mul__(self, other):
        """self * other"""
        # TODO
        raise NotImplementedError

    def __pow__(self, k):
        """self ** k for a plain int or float k (not a Value)."""
        # TODO
        raise NotImplementedError

    def exp(self):
        # TODO
        raise NotImplementedError

    def log(self):
        """natural logarithm"""
        # TODO
        raise NotImplementedError

    def tanh(self):
        # TODO
        raise NotImplementedError

    def relu(self):
        """max(0, x); the derivative at exactly 0 is 0."""
        # TODO
        raise NotImplementedError

    # --- derived operations: build them from the primitives above (no new backward code)
    def __neg__(self):
        # TODO
        raise NotImplementedError

    def __sub__(self, other):
        # TODO
        raise NotImplementedError

    def __truediv__(self, other):
        # TODO
        raise NotImplementedError

    def __radd__(self, other):   # number + Value
        return self + other

    def __rmul__(self, other):   # number * Value
        return self * other

    def __rsub__(self, other):   # number - Value
        # TODO
        raise NotImplementedError

    def __rtruediv__(self, other):   # number / Value
        # TODO
        raise NotImplementedError

    def __repr__(self):
        return "Value(data=%g, grad=%g)" % (self.data, self.grad)

    def backward(self):
        """Compute the gradient of self with respect to every Value it depends on.

        1. Order all Values of the graph so that every Value comes after its parents
           (a topological order). Do NOT use recursion: a graph can be thousands of
           operations deep and Python's recursion limit is 1000.
        2. Set every grad in the graph to 0, then self.grad = 1.
        3. Walk the order backwards and call each Value's _backward().
        Calling backward() twice gives the same grads (they are recomputed, not added up).
        """
        # TODO
        raise NotImplementedError
