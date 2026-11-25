# 11 - Merging an adapter into the weights

## Concept

A LoRA layer computes `y = W x + (alpha / r) * B (A x)`. Matrix multiplication distributes, so this is the same as
`y = (W + (alpha / r) * B A) x`. The adapter is a *factored* weight update, and you can multiply it out once and put the
result into `W`. This is **merging**: afterwards there are no adapters, no extra matrix products, no extra file, and the
model is an ordinary GPT with the new behaviour built in. Anything that can load the original model (a serving stack, a
quantiser, your lesson 01 harness) can load the merged one.

"Same outputs" is a claim you can test, so test it: run both models on the same tokens and compare the logits. They will not
be bit-identical (floating point addition is not associative, so `W x + s B A x` and `(W + s B A) x` differ in the last
digits) but the difference must be tiny, around `1e-6`; verify uses `1e-4`. A bigger gap means a bug, usually a wrong scale
(forgetting `alpha / r`) or a transposed matrix.

When should you merge, and when keep the adapter separate?

- **Merge** to ship one model for one task: lowest latency (the adapter's two extra matmuls per layer disappear), simplest
  deployment, a single file.
- **Keep separate** when many tasks share one base (lesson 12: one copy of the base in memory, a small adapter per task, swapped
  per request), when you may still want to retrain or remove the adapter (you cannot un-merge unless you kept `A` and `B`),
  or when you want to scale the adapter's strength up or down at inference.
- **Merging into a quantised base** loses precision: you cannot add a small update into 8-bit weights without re-quantising
  (lesson 13). Quantised deployments usually merge into the full-precision weights first and quantise after.

A merged checkpoint keeps the **same parameter names and shapes** as the original, so `load_state_dict` into a fresh GPT
works with no changes. The test checks that as well as the numbers.

## The situation

`merge.py` imports `LoRALinear` from your `lora.py`. `run_merge.py` trains an adapter for 100 steps, merges a copy,
compares losses and logits, and writes `models/style_merged.pt` as a normal checkpoint.

## Your task

Implement `merged_weight`, `merge_lora`, `merged_copy`, `max_logit_difference` and `save_merged_checkpoint`. Verify checks the
formula (also with `alpha / r` not equal to 1), the logit equality of a model with random adapters on every layer type before and
after merging, that the merged model has exactly the original names, shapes and parameter count and loads into a plain GPT,
that merging a merged model does nothing, that `merged_copy` leaves the original alone, the checkpoint round trip, and a
real trained adapter: same held-out loss after merging (within 0.001) and at least 0.2 nats better than the base. Then:

    make py F=run_merge.py     # about 15 s

Compare the byte counts it prints: the adapter is a tenth of the size of the merged model, and the merged model is a whole model.

## Useful commands

- `make py F=run_merge.py`; `ls -l ~/kdrill-work/fine-tuning/models ~/kdrill-work/fine-tuning/adapters`
- `kdrill hint`, `kdrill reset`

## On a real project

`peft` offers `merge_and_unload()`. Merging is done in the dtype you serve in, and often checked with a small evaluation
(the same numbers before and after), exactly like this lesson. Some servers apply adapters on the fly instead (vLLM, LoRAX)
so that one GPU can serve hundreds of adapters.

## Read more

- LoRA: Low-Rank Adaptation of Large Language Models (section 4.1, no additional inference latency): https://arxiv.org/abs/2106.09685
- Hugging Face PEFT, merge LoRA weights: https://huggingface.co/docs/peft/developer_guides/lora#merge-lora-weights-into-the-base-model
- S-LoRA: Serving Thousands of Concurrent LoRA Adapters: https://arxiv.org/abs/2311.03285
