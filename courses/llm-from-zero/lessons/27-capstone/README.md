# 27 - Capstone: the whole pipeline on a corpus of your choice

## Concept

You have built every part. A project is not the parts; it is the **pipeline that connects them**,
runs the same way every time, and leaves behind artifacts someone else can use without asking you
anything.

The pipeline: **gather** (lesson 01) -> **clean, deduplicate, split** (02 to 05, `build_dataset`
in 06) -> **tokenize** (BPE trained on the training split only, 08) -> **train** (GPT, schedule,
clipping, checkpoints, 18 to 22) -> **evaluate on the test split, once** (26) -> **sample** (24) ->
**write down what you made** (data card from lesson 06, a model card here). Each arrow is a place
where leakage can creep in, so the capstone test watches the important one: the test split is used
only after training, the tokenizer sees only training text, and `train_run` gets exactly the encoded
train and validation splits.

The output is a **checkpoint with a contract**. A bare `state_dict` is useless a month later: you
need the architecture hyperparameters to rebuild the model, the tokenizer to feed it text, the
metrics to know how good it was, the training config to reproduce it, and the data card to know what it
read. That is why the checkpoint here carries `model_state`, `gpt_config`, `tokenizer`, `metrics`,
`train_config` and `data_card`, and why `load_for_finetuning` reconstructs a working model from the file
alone. The `fine-tuning` course starts from exactly this file.

A **model card** (Mitchell et al., 2019) is the human-readable half: what the model is, what data it
saw, how it was trained, how it was measured, example outputs, and (the part to write with care) what it
is for and what it is not for. It is also where honesty about limits lives.

The test of the whole thing is the reproducibility check: the same corpus and config give the same
numbers. If they do not, something is unseeded; if they do, you have a pipeline.

## The situation

`capstone.py` wires your earlier modules together: `build_dataset`, `BPE`, `GPT`, `train_run`, `generate`,
`perplexity_on_text`, `bits_per_char`. The docstring of `run_pipeline` lists every step and the exact
checkpoint contract. `capstone_run.py` runs it on a directory of your choice.

## Your task

1. Implement `run_pipeline`, `load_for_finetuning` and `make_model_card`. In the model card, write the
   *Intended use and limitations* section in your own words.
2. Verify runs the full pipeline on a small generated corpus (five "books" of templated sentences with
   Gutenberg headers) in under a minute and checks: the outputs exist; the model learned (losses well below
   `ln V`); the checkpoint contract and that `load_for_finetuning` reproduces the stored test loss;
   the model card's sections, numbers, samples and quoted data-card sources; that the test split never
   reaches training and the tokenizer is trained on the training split only; and that two runs give
   identical results.
3. Then do it for real, on a corpus of your choice: put a few `.txt` files in `data/my_corpus/` (another
   author from Project Gutenberg, with lesson 01's fetcher; or text you wrote) and run
   `make py F=capstone_run.py ARGS="data/my_corpus"` (about 4 minutes). Read your two cards and the samples.
   Be critical: what would you change in the data first?

## Useful commands

- `ls ~/kdrill-work/llm-from-zero/out/capstone/`
- `kdrill py`: `from capstone import load_for_finetuning; m, t = load_for_finetuning("out/capstone/checkpoint.pt")`
- `kdrill hint`; `kdrill solution`.

## On a real project

Put the pipeline in version control, pin the data by checksum, log every run with its config and
metrics, publish the model with its card (for example on the Hugging Face Hub), and keep the evaluation
script next to the model so the number can be reproduced.

## Read more

- Model Cards for Model Reporting: https://arxiv.org/abs/1810.03993
- Hugging Face model cards: https://huggingface.co/docs/hub/model-cards
- Neural Networks: Zero to Hero (the inspiration for this course): https://karpathy.ai/zero-to-hero.html
