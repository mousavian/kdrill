import pytest
import torch
import torch.nn as nn

import finetune
import lora as L
import quant as Q
from kdlib import kdtest, refimpl as I, tasks as T


@pytest.fixture(scope="module")
def world():
    m, tok = I.ref_base()
    return m, tok, I.ids_of(tok, T.alice("train")), I.ids_of(tok, T.alice("val"))[:3000]


def test_no_libraries():
    """written by hand: no bitsandbytes, peft, transformers, torch.quantization"""
    kdtest.assert_no_imports("quant", {"bitsandbytes", "peft", "transformers", "accelerate", "auto_gptq", "optimum"})
    kdtest.assert_not_used("quant", {"quantize_dynamic", "quantize_per_tensor", "quantize_per_channel", "fake_quantize_per_tensor_affine"})


def test_quantize_values_and_ranges():
    """absmax per row: scales are row max / 127, the largest entry of each row maps to +-127, codes are int8 within range, zero rows are safe"""
    w = torch.tensor([[0.0, 1.27, -0.635], [1.0, -4.0, 2.4], [0.0, 0.0, 0.0]])
    q, s = Q.quantize(w)
    assert q.dtype == torch.int8 and s.dtype == torch.float32 and s.shape == (3, 1)
    assert s[0, 0] == pytest.approx(1.27 / 127) and s[1, 0] == pytest.approx(4.0 / 127) and s[2, 0] == 1.0
    assert q[0].tolist() == [0, 127, -64] or q[0].tolist() == [0, 127, -63]
    assert q[1].tolist() == [32, -127, 76] and q[2].tolist() == [0, 0, 0]
    q4, s4 = Q.quantize(w, bits=4)
    assert int(q4.abs().max()) == 7 and q4[1].tolist() == [2, -7, 4]
    qt, st = Q.quantize(w, per_row=False)
    assert st.shape == (1, 1) and st[0, 0] == pytest.approx(4.0 / 127) and int(qt.abs().max()) == 127
    assert torch.equal(Q.dequantize(q, s), q.float() * s)


def test_roundtrip_error_and_outliers():
    """int8 per-row has under 1% relative error on a random matrix, 4-bit is clearly worse, and one outlier ruins a per-tensor scale but not a per-row one"""
    torch.manual_seed(0)
    w = torch.randn(64, 96) * 0.05
    e8, e4 = Q.quantization_error(w, 8), Q.quantization_error(w, 4)
    assert e8 < 0.01 and e4 > 5 * e8 and e4 < 0.2, (e8, e4)
    w2 = w.clone()
    w2[3, 5] = 4.0                                      # one outlier
    row, tensor = Q.quantization_error(w2, 8, per_row=True), Q.quantization_error(w2, 8, per_row=False)
    assert tensor > 3 * row, "per-tensor %.4f vs per-row %.4f" % (tensor, row)


def test_quant_linear_layer():
    """QuantLinear has buffers and no parameters, int8 weights, the bias kept, and its output is close to the float layer's"""
    torch.manual_seed(1)
    lin = nn.Linear(32, 10)
    ql = Q.QuantLinear(lin)
    assert list(ql.parameters()) == [] and ql.qweight.dtype == torch.int8 and ql.in_features == 32 and ql.out_features == 10
    assert torch.equal(ql.bias, lin.bias)
    x = torch.randn(4, 7, 32)
    assert torch.allclose(ql(x), lin(x), atol=0.05) and not torch.equal(ql(x), lin(x))
    nb = Q.QuantLinear(nn.Linear(8, 3, bias=False))
    assert nb.bias is None and nb(torch.randn(2, 8)).shape == (2, 3)
    assert Q.QuantLinear(lin, bits=4).qweight.abs().max() <= 7


def test_quantize_model_memory_and_quality(world):
    """int8 base: all 45 transformer linears replaced, the model needs under 45% of the float bytes, and the held-out loss moves by less than 0.02"""
    m, tok, tr, va = world
    mm = I.clone(m)
    n = Q.quantize_model(mm)
    assert n == 3 * (3 * 4 + 1 + 2)
    assert not any(isinstance(x, nn.Linear) and name != "lm_head" for name, x in mm.named_modules())
    assert Q.model_bytes(m) == 4 * 384864
    assert Q.model_bytes(mm) < 0.45 * Q.model_bytes(m), "%d of %d bytes" % (Q.model_bytes(mm), Q.model_bytes(m))
    assert mm.tok_emb.weight.dtype == torch.float32 and all(p.dtype == torch.float32 for p in mm.parameters())
    a, b = I.text_loss(m, va), I.text_loss(mm, va)
    assert abs(a - b) < 0.02, "loss %.4f -> %.4f after int8" % (a, b)
    m4 = I.clone(m)
    Q.quantize_model(m4, bits=4)
    c = I.text_loss(m4, va)
    assert c > b + 0.02, "4-bit should lose clearly more than 8-bit: %.4f vs %.4f" % (c, b)


def test_qlora_trains_adapters_on_a_quantised_base(world):
    """add_lora, then quantise the base under it: A and B stay float and trainable, the int8 codes never change, and 100 steps lower the 4-bit model's style loss by at least 0.3"""
    m, tok, tr, va = world
    mm = I.clone(m)
    L.add_lora(mm, r=8, alpha=16)
    n_train = L.trainable_count(mm)
    n = Q.quantize_model(mm, bits=4)
    assert n == 3 * (3 * 4 + 1) + 6, n            # 39 bases under adapters + the 6 plain MLP layers
    assert L.trainable_count(mm) == n_train == 39168
    codes = {k: v.clone() for k, v in mm.state_dict().items() if k.endswith("qweight")}
    assert len(codes) == n
    before = I.text_loss(mm, va)
    finetune.finetune(mm, tr, steps=100, lr=3e-3, warmup=10)
    after = I.text_loss(mm, va)
    assert all(torch.equal(v, mm.state_dict()[k]) for k, v in codes.items()), "the quantised weights must stay frozen"
    assert after < before - 0.3, "4-bit base: style loss %.3f -> %.3f with adapters" % (before, after)
