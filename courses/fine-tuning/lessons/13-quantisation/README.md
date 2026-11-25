# 13 - Quantisation basics and the idea of QLoRA

## Concept

Weights are stored as 32-bit floats. Most of a trained model's information survives in far fewer bits: store each weight as an
8-bit integer plus a shared floating-point **scale**, and the model shrinks to a quarter of its size for the matrices that
dominate it. That is **quantisation**. The simplest form is **absmax** (symmetric) quantisation:

    scale = max|w| / 127           q = round(w / scale)  (an integer from -127 to 127)           w ~ q * scale

The rounding error of one weight is at most `scale / 2`. Two choices decide how good it is:

- **One scale for what?** A scale per *whole matrix* is dragged up by the single largest weight; every other weight then
  uses only a few of the 255 levels. A scale per *row* (per output unit) confines an outlier to its own row. Large models have
  strong outliers (the LLM.int8 paper), which is why finer-grained scales matter; the test plants one outlier and measures.
- **How many bits?** 8 bits is almost free; 4 bits (only 15 levels) costs real quality, which is where the next idea comes in.

**QLoRA** is the combination: keep the **frozen base** in 4-bit, rebuild each weight matrix on the fly in the forward pass
(`dequantize`, then multiply), and train **LoRA adapters in full precision** on top. Gradients flow *through* the quantised
layers to the adapters; the quantised weights are never updated (they cannot be: they are integers). The adapter learns to
make up for the damage quantisation did and, at the same time, the new task. That is why a 65-billion-parameter model could be
fine-tuned on one GPU: the base costs a quarter of a byte per weight, and only the small adapters need gradients and optimizer
state.

In this lesson 4-bit values live in int8 containers (no bit-packing), so the byte counts show the 8-bit saving; real 4-bit storage
packs two values per byte and halves the weights again. Embeddings, norms and biases stay float32: they are a small share of
the model and quantising them hurts quality disproportionately.

## The situation

`quant.py` has `quantize`/`dequantize`, an error measure, `QuantLinear`, `quantize_model` and `model_bytes`. `run_quant.py` measures
float, int8 and 4-bit bases, then trains adapters on top of int8 and 4-bit bases with your lesson 08 and 02 code. Note the order: `add_lora`
first, then `quantize_model`, whose default names include `base` so it reaches the frozen layer *inside* each adapter layer.

## Your task

Implement the six pieces. Verify checks the quantiser on hand-made values (scales, codes, zero rows, 4-bit range, per-tensor scale),
the round-trip error (int8 under 1 percent, 4-bit clearly worse) and the outlier effect (per-tensor at least 3 times worse than
per-row), `QuantLinear` (buffers only, int8 codes, bias kept, close to the float layer), the whole model (all 45 transformer layers
replaced, under 45 percent of the bytes, held-out loss within 0.02 of float, 4-bit clearly worse than 8-bit), and QLoRA training
(adapters trainable and unchanged in count, the integer codes bit-identical afterwards, the 4-bit model's style loss at least 0.3
lower after 100 steps). `bitsandbytes` and `torch.quantization` are forbidden. Then:

    make py F=run_quant.py       # about 30 s

Reference numbers: float32 1,539,456 bytes; int8 554,496 bytes (36 percent) with the Holmes loss moving from 2.9232 to 2.9238; 4-bit
(in int8 containers) the same bytes but 3.008; int8 base plus LoRA 3.22 on Alice, 4-bit base plus LoRA 3.24 (the 4-bit base alone is
3.54): the adapters win back what quantisation cost on the new text and then some.

## Useful commands

- `make py F=run_quant.py`; `cat results/quant.json`
- `kdrill hint`, `kdrill reset`

## On a real project

QLoRA uses a 4-bit data type tuned for normally distributed weights (NF4), block-wise scales (one per 64 weights) with the scales
themselves quantised, and paged optimizers. GPTQ and AWQ quantise for inference using calibration data. The accuracy cost depends on
the model size: big models tolerate 4 bits far better than a 0.4-million-parameter one, which is why the 4-bit row here looks worse than
you will see in practice.

## Read more

- QLoRA: Efficient Finetuning of Quantized LLMs: https://arxiv.org/abs/2305.14314
- LLM.int8(): 8-bit Matrix Multiplication for Transformers at Scale: https://arxiv.org/abs/2208.07339
- A Survey of Quantization Methods for Efficient Neural Network Inference: https://arxiv.org/abs/2103.13630
