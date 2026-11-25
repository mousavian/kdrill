"""Lesson 13 - quantised frozen weights, written by hand (no bitsandbytes). Builds on lora.py (lesson 08)."""
import torch
import torch.nn as nn


def quantize(w, bits=8, per_row=True):
    """Symmetric absmax quantisation of a float matrix w (out, in). qmax = 2 ** (bits - 1) - 1 (127 for 8 bits, 7 for 4).
    scale = max|w| / qmax over each row (per_row=True, shape (out, 1)) or over the whole matrix (shape (1, 1));
    a scale of 0 becomes 1.0 (all-zero rows). q = round(w / scale) clamped to [-qmax, qmax], returned as an int8 tensor
    (4-bit values live in int8 containers here). Return (q, scale) with scale float32."""
    # TODO
    raise NotImplementedError


def dequantize(q, scale):
    """The float32 matrix q * scale."""
    # TODO
    raise NotImplementedError


def quantization_error(w, bits=8, per_row=True):
    """Relative error ||w - dequantize(quantize(w))||_F / ||w||_F as a float."""
    # TODO
    raise NotImplementedError


class QuantLinear(nn.Module):
    """A frozen linear layer whose weight is stored quantised. No nn.Parameter at all: register_buffer("qweight", int8),
    register_buffer("scale", float32) and, when the source layer had a bias, register_buffer("bias", float32 copy).
    Attributes in_features and out_features. forward(x) = x @ dequantize(qweight, scale).T (+ bias): the weight is
    rebuilt on the fly, as in QLoRA. __init__(linear, bits=8, per_row=True) takes an nn.Linear."""

    def __init__(self, linear, bits=8, per_row=True):
        super().__init__()
        # TODO
        raise NotImplementedError

    def forward(self, x):
        # TODO
        raise NotImplementedError


def quantize_model(model, bits=8, per_row=True, names=("key", "query", "value", "proj", "fc1", "fc2", "base")):
    """Replace in place every nn.Linear that is a direct child under an attribute name in `names` by a QuantLinear
    (the name 'base' reaches the frozen layer inside a LoRALinear, so a model that already has adapters keeps its
    adapters in float and only its base is quantised). Embeddings, norms and everything else stay float32.
    Return the number of layers replaced."""
    # TODO
    raise NotImplementedError


def model_bytes(model):
    """Memory of the model's parameters AND buffers in bytes: sum of numel * element_size(). Int8 buffers count 1 byte
    per value, even for 4-bit values (they are stored in int8 containers here)."""
    # TODO
    raise NotImplementedError
