# 08 - LoRA from scratch

## Concept

Full fine-tuning changes a weight matrix `W` (out x in) into `W + dW` where `dW` can be any matrix, and it needs
gradients and optimizer state for all of `W`. **LoRA** (low-rank adaptation) makes a bet: the useful change `dW` is
**low rank**. So it never trains `W`. It freezes it and learns `dW` as a product of two thin matrices:

    dW = (alpha / r) * B @ A          A: (r, in)   B: (out, r)   r much smaller than in and out

and the layer computes `y = W x + (alpha / r) * B (A x)`. The trainable count per layer drops from `out * in` to
`r * (in + out)`; here an attention layer of 96 by 96 with `r = 8` trains 1,536 numbers instead of 9,216.

The details that make it work:

- **B starts at zero, A starts random.** So `dW = 0` and the adapted model is *exactly* the base model at step 0; training
  starts from the behaviour you already have. (The gradient of `A` is zero until `B` moves, as the test shows: `B` moves
  first, then `A` follows.) Starting both at random would corrupt the model before any learning.
- **`alpha / r` scaling.** The product is multiplied by `alpha / r` so that you can change the rank without retuning the
  learning rate: doubling `r` with `alpha = 2r` keeps the update size comparable. Lesson 09 explores this.
- **The base is shared, not copied**, and frozen: the adapter wraps the existing layer.
- **Which layers.** The paper adapts the attention projections; here that means each head's `query`, `key`, `value` and the output
  `proj`. Lesson 10 asks whether that is enough.
- **The adapter is a file.** After training you keep only `A` and `B` (plus `r` and `alpha`): a fraction of the model's size, which
  is why one base model can serve many tasks (lesson 12).

The `finetune()` of lesson 02 trains whatever has `requires_grad=True`, so it trains the adapter unchanged.

## The situation

`lora.py` has the wrapper and five functions; `run_lora.py` wraps the attention layers (rank 8), trains 150 steps with
your `finetune()` and prints the style loss, the trainable share and the adapter size.

## Your task

Implement `LoRALinear`, `add_lora`, `lora_parameters`, `trainable_count`, `save_adapter` and `load_adapter`. Verify
checks the initial equality with the base layer (exactly), the formula with a non-zero `B`, the gradients (none on the
base; `B` only, at the start), the wrapping of the GPT (names, unchanged logits at the start, everything else frozen, the
trainable count against the formula `r * (in + out)` summed over layers), errors, a training run that moves only `A` and
`B` (every other tensor bit-identical) and gains at least 0.2 nats of style loss, and the adapter file (small, round trip,
another rank refused). `peft` and friends are forbidden. Then:

    make py F=run_lora.py      # about 20 s

Reference: 39,168 trainable parameters (10 percent of the model), an adapter of about 176 KB against the 1.5 MB
checkpoint, style loss around 3.18 (base 3.46, full fine-tuning about 3.0) and original loss around 3.03. LoRA at this budget
closes about two thirds of the gap that full fine-tuning closes, with a tenth of the trainable parameters.

## Useful commands

- `make py F=run_lora.py`; `ls -l ~/kdrill-work/fine-tuning/adapters/`
- `kdrill hint`, `kdrill reset`

## On a real project

`peft` wraps the same idea for Hugging Face models (`LoraConfig(r, lora_alpha, target_modules)`), usually with dropout on the
adapter input, and also offers rank-stabilised scaling (`alpha / sqrt(r)`) and variants (DoRA, LoRA+). The mechanics you wrote are
the whole algorithm.

## Read more

- LoRA: Low-Rank Adaptation of Large Language Models: https://arxiv.org/abs/2106.09685
- Intrinsic Dimensionality Explains the Effectiveness of Language Model Fine-Tuning: https://arxiv.org/abs/2012.13255
- Hugging Face PEFT, LoRA guide: https://huggingface.co/docs/peft/conceptual_guides/lora
