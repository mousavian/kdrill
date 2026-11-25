"""Helpers for the hidden tests."""
import ast
import os
import sys

WORK = "/work"


def source_of(modname):
    path = os.path.join(WORK, modname + ".py")
    with open(path, encoding="utf-8") as f:
        return f.read()


def imported_modules(modname):
    """Top-level names imported anywhere in /work/<modname>.py (import x.y -> x)."""
    tree = ast.parse(source_of(modname))
    names = set()
    for n in ast.walk(tree):
        if isinstance(n, ast.Import):
            names.update(a.name.split(".")[0] for a in n.names)
        elif isinstance(n, ast.ImportFrom) and n.module and n.level == 0:
            names.add(n.module.split(".")[0])
    return names


def used_names(modname):
    """Every identifier and attribute name that appears in the source (not strings/comments)."""
    tree = ast.parse(source_of(modname))
    names = set()
    for n in ast.walk(tree):
        if isinstance(n, ast.Name):
            names.add(n.id)
        elif isinstance(n, ast.Attribute):
            names.add(n.attr)
        elif isinstance(n, (ast.Import, ast.ImportFrom)):
            for a in n.names:
                names.add(a.name.split(".")[-1])
    return names


def assert_no_imports(modname, forbidden, why=""):
    bad = sorted(imported_modules(modname) & set(forbidden))
    assert not bad, "%s.py must not import %s%s" % (modname, ", ".join(bad), (" (" + why + ")") if why else "")


def assert_not_used(modname, forbidden, why=""):
    bad = sorted(used_names(modname) & set(forbidden))
    assert not bad, "%s.py must not use %s%s" % (modname, ", ".join(bad), (" (" + why + ")") if why else "")


def fresh_import(modname):
    """Import /work/<modname>.py again from disk."""
    import importlib
    sys.modules.pop(modname, None)
    importlib.invalidate_caches()
    return importlib.import_module(modname)


def numeric_grad(f, x, eps=1e-5):
    """Central finite differences of scalar f over every entry of numpy array x (modified in place and restored)."""
    import numpy as np
    g = np.zeros_like(x, dtype=np.float64)
    it = np.nditer(x, flags=["multi_index"], op_flags=["readwrite"])
    while not it.finished:
        i = it.multi_index
        old = x[i]
        x[i] = old + eps
        up = f()
        x[i] = old - eps
        dn = f()
        x[i] = old
        g[i] = (up - dn) / (2 * eps)
        it.iternext()
    return g
