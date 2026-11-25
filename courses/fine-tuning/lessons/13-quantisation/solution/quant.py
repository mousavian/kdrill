"""Lesson 13 - reference solution."""
import torch
import torch.nn as nn


def quantize(w, bits=8, per_row=True):
    qmax = 2 ** (bits - 1) - 1
    w = w.detach().float()
    amax = w.abs().amax(dim=1, keepdim=True) if per_row else w.abs().max().reshape(1, 1)
    scale = amax / qmax
    scale = torch.where(scale == 0, torch.ones_like(scale), scale)
    q = torch.round(w / scale).clamp(-qmax, qmax).to(torch.int8)
    return q, scale.float()


def dequantize(q, scale):
    return q.float() * scale


def quantization_error(w, bits=8, per_row=True):
    q, s = quantize(w, bits, per_row)
    return float((w - dequantize(q, s)).norm() / w.norm())


class QuantLinear(nn.Module):
    def __init__(self, linear, bits=8, per_row=True):
        super().__init__()
        self.in_features, self.out_features = linear.in_features, linear.out_features
        q, s = quantize(linear.weight, bits, per_row)
        self.register_buffer("qweight", q)
        self.register_buffer("scale", s)
        if linear.bias is not None:
            self.register_buffer("bias", linear.bias.detach().clone().float())
        else:
            self.bias = None

    def forward(self, x):
        y = x @ dequantize(self.qweight, self.scale).T
        return y if self.bias is None else y + self.bias


def quantize_model(model, bits=8, per_row=True, names=("key", "query", "value", "proj", "fc1", "fc2", "base")):
    n = 0
    for _, mod in list(model.named_modules()):
        for cname, child in list(mod.named_children()):
            if isinstance(child, nn.Linear) and cname in names:
                setattr(mod, cname, QuantLinear(child, bits, per_row))
                n += 1
    return n


def model_bytes(model):
    return sum(t.numel() * t.element_size() for t in list(model.parameters()) + list(model.buffers()))
