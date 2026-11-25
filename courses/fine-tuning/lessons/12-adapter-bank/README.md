# 12 - Several adapters on one base

## Concept

The practical payoff of a small adapter is that **one base model can serve many tasks**. Instead of one full model per task
(a second, a third, a tenth copy of every weight), keep a single copy of the base in memory and a small adapter for each task,
and pick the adapter **per request**: the style adapter for one customer, the question-answering adapter for another, none at
all for a third. The base is the expensive part (here 1.5 MB, in real life tens of gigabytes); an adapter is a few percent of it.

Switching has to be **exact** and **isolated**:

- *Exact*: with adapter `x` active the output must be what a model trained with `x` alone would give, and with no adapter the
  output must be the plain base's. If switching leaves a trace of the previous adapter, outputs depend on request order.
- *Isolated*: training adapter `b` must never change adapter `a`. Each adapter owns its tensors; a new adapter starts from
  scratch (random `A`, zero `B`), not from whatever the last one learned.

How the bank here works: the model carries one set of LoRA layers (the "slots"). Each adapter is a dictionary of A and B tensors
kept outside. `activate(name)` first writes the live tensors back into the adapter that was active (so work done in place is
kept), then copies the chosen adapter into the live layers; `activate(None)` zeroes every `B`, which is exactly the base model.
Copying *into* the existing parameters (rather than replacing them) keeps any optimizer that holds them valid.

The experiment is a comparison across tasks: a style adapter trained on Alice and a question-answering adapter trained on the
format task, each evaluated on **both** tasks. Expect a diagonal: each adapter is good at its own task and does nothing for the
other. A single adapter trained on a mix would be a different, interesting experiment (and a risk of interference) for the capstone.

## The situation

`adapters.py` describes `AdapterBank` method by method (the docstring is the specification) and imports `add_lora` and
`lora_parameters` from your lesson 08. `run_adapters.py` trains the two adapters with your `finetune` and `train_sft` and
prints the cross table and the memory report.

## Your task

Implement `AdapterBank`. Verify checks that the bank wraps your model in place and the base parameters are shared, that a fresh
adapter changes nothing, that errors are raised (duplicate, unknown, removing the active one), that added adapters have different
`A` and zero `B` and that `state()` returns copies, that after real training of two adapters each keeps its weights across
switches (identical logits when switching back and forth, `None` equals the base, training one does not change the other), the
memory arithmetic, and a two-task outcome run: the style adapter lowers held-out style loss by at least 0.2 and does not answer
in the format; the question-answering adapter reaches at least 90 percent format and beats the style adapter in exact match.
Then:

    make py F=run_adapters.py     # about 30 s

Reference table: no adapter 3.46 style loss, format 0, exact 0; the style adapter 3.06, format 0, exact 0; the question-answering
adapter format 1.00, exact about 0.5, and a style loss of 5.3: the format adapter makes the model much *worse* at ordinary text,
which is exactly why you switch adapters per request instead of leaving one on. Two adapters of 249 KB share one 1.54 MB base; with
ten tasks it is 4 MB against 15 MB.

## Useful commands

- `make py F=run_adapters.py`; `cat results/adapters.json`
- `kdrill hint`, `kdrill reset`

## On a real project

Servers such as vLLM and LoRAX keep many adapters resident and batch requests that use different adapters into one forward pass
(S-LoRA). Adapter files are versioned and routed by customer or task name; the base is loaded once. The thing to watch is the quality
of each adapter *and* of the base after upgrades: a new base invalidates every adapter trained on the old one.

## Read more

- S-LoRA: Serving Thousands of Concurrent LoRA Adapters: https://arxiv.org/abs/2311.03285
- LoRA Soups: Merging LoRAs for Practical Skill Composition Tasks: https://arxiv.org/abs/2410.13025
- Hugging Face PEFT, working with multiple adapters: https://huggingface.co/docs/peft/developer_guides/lora#load-adapters
