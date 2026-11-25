"""Lesson 12 - reference solution."""
import torch

from lora import ATTENTION, LoRALinear, add_lora, lora_parameters

MLP = ("fc1", "fc2")


class AdapterBank:
    def __init__(self, model, targets=ATTENTION + MLP, r=8, alpha=16.0, seed=0):
        self.model, self.seed, self.r = model, seed, r
        add_lora(model, targets, r, alpha, seed)
        self._live = dict(lora_parameters(model))
        self._store = {}
        self._active = None

    def names(self):
        return list(self._store)

    @property
    def active(self):
        return self._active

    def _sync(self):
        if self._active is not None:
            self._store[self._active] = {n: p.detach().clone() for n, p in self._live.items()}

    def add(self, name):
        if name in self._store:
            raise ValueError("adapter %r exists" % name)
        g = torch.Generator().manual_seed(self.seed + len(self._store))
        st = {}
        for n, p in self._live.items():
            if n.endswith("lora_A"):
                t = torch.empty_like(p)
                torch.nn.init.kaiming_uniform_(t, a=5 ** 0.5, generator=g)
            else:
                t = torch.zeros_like(p)
            st[n] = t
        self._store[name] = st

    def activate(self, name):
        if name is not None and name not in self._store:
            raise ValueError("unknown adapter %r" % (name,))
        self._sync()
        with torch.no_grad():
            if name is None:
                for n, p in self._live.items():
                    if n.endswith("lora_B"):
                        p.zero_()
            else:
                for n, p in self._live.items():
                    p.copy_(self._store[name][n])
        self._active = name

    def state(self, name):
        if name not in self._store:
            raise ValueError("unknown adapter %r" % (name,))
        if name == self._active:
            self._sync()
        return {n: t.clone() for n, t in self._store[name].items()}

    def remove(self, name):
        if name == self._active:
            raise ValueError("cannot remove the active adapter")
        if name not in self._store:
            raise ValueError("unknown adapter %r" % (name,))
        del self._store[name]

    def memory_report(self):
        base = sum(p.numel() for n, p in self.model.named_parameters() if not (n.endswith("lora_A") or n.endswith("lora_B")))
        per = sum(p.numel() for p in self._live.values())
        return {"base_bytes": 4 * base, "adapter_bytes": {n: 4 * per for n in self._store},
                "separate_models_bytes": len(self._store) * 4 * base}
