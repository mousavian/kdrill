# 17 - Capstone: a task of your own, evaluated honestly

## Concept

You have the parts: a harness (01), full fine-tuning and its costs (02 to 04), data work (05 to 07), LoRA and what comes with it (08 to 13),
preferences (14, 15) and ways to trust a number (16). A fine-tuning *project* is the pipeline that connects them, run the same way every time,
that leaves behind an artifact and a report someone else can rely on.

The pipeline of this capstone, for a question-answer task:

1. **Clean** the training rows (lesson 05) and **remove contamination**: any training row that shares a question with the evaluation set
   goes (lesson 16). Report how many. The evaluation questions must never reach training, and the test watches the examples that `train_sft` receives.
2. **Measure the base first** on the held-out questions and on its original text (lesson 01): without that, "improved" means nothing.
3. **Choose full or LoRA** and say why. You have the numbers: LoRA trains 62 thousand parameters and saves a 250 KB adapter, full fine-tuning trains
   385 thousand and needs a whole model per task (lessons 02, 03, 08); which one scores better on *your* task, and which one forgets more of the original
   text, is for the run to say (the reference run on the course's task has LoRA ahead on exact match).
4. **Tune over several seeds** (lesson 16) and report the mean and the spread, not the best seed.
5. **Save the artifact** (an adapter or a tuned checkpoint) and a **results file**. The reported numbers must be reproducible from the artifact: the
   test loads your saved adapter into a fresh base, evaluates it, and compares with your `results.json`.
6. **Write the model card** with the numbers *from the results*, and a limitations section in your own words.

An honest report states what the model cannot do. A model that gets 95 percent on 40 held-out questions of a toy task is not "95 percent accurate": it
answers a tiny closed set of questions, and one question moves the score by 2.5 points. Writing that sentence is part of the work.

## The situation

`capstone.py` imports your earlier modules (`sft_data`, `masking`, `lora`, `harness`, `trust`) and fixes the contract in the docstrings of `run_capstone`
(every step, every field of the results) and `make_model_card` (the six headings). `capstone_run.py` runs LoRA and full fine-tuning on your task with three
seeds each.

## Your task

1. Implement `run_capstone` and `make_model_card`. Verify runs the pipeline on a **new task** you have not seen (who owns which thing, with names and
   phrasings that are not in the course data), with the evaluation questions planted in the training file, and checks: the contract of the results and the
   artifact; the contamination removal (the items given to `train_sft` contain no evaluation question; duplicates cleaned); the base answers nothing in
   the format and the tuned model at least 90 percent in format and 70 percent exactly right; that evaluating your **saved adapter** in a fresh base
   gives exactly your reported numbers; the model card (sections in order, all numbers, your limitations text); method `full`, several seeds and the
   sample deviation; and errors for an unknown method and for empty data. The tests always use the course's reference base so your result does not
   depend on which base you have. `peft`, `trl` and the like are forbidden.
2. Then do it for real, on a task of your choice: write 100 or more `{"question", "answer"}` lines to `data/my_task/train.jsonl` and 30 or more to
   `data/my_task/eval.jsonl` (facts about something you know, a persona's answers, unit conversions, a house style for replies; keep answers short so the format
   is learnable and the answers checkable), edit `LIMITATIONS` in `capstone_run.py`, and run

       make py F=capstone_run.py ARGS="data/my_task"      # about 50 s

   On the course's own task the reference run gives, over three seeds: LoRA exact match 0.59 (spread 0.09), full fine-tuning 0.37 (spread 0.12), both
   100 percent in format, and the loss on the original Holmes text going from 2.96 to 5.04 (LoRA) and 4.08 (full): a format-and-facts task trained for a few
   hundred steps with no replay wrecks the model as a general text model. The model card should say so (and lesson 03 tells you what to do about it).

   Read both model cards. Which method would you ship, and what would you do with more data, more seeds, a better evaluation?

## Useful commands

- `make py F=capstone_run.py`; `cat ~/kdrill-work/fine-tuning/out/capstone_lora/MODEL_CARD.md`
- `kdrill py`: `from base import *; m, tok = load_base()`
- `kdrill hint`, `kdrill reset`

## On a real project

The same shape appears as a training script with a config file, an experiment tracker, an evaluation suite, a model registry and a published model card. Two
things carry over unchanged from this lesson: the evaluation set is decided before training and checked for contamination, and every number in the report can
be regenerated from the saved artifact and the config.

## Read more

- Model Cards for Model Reporting: https://arxiv.org/abs/1810.03993
- Hugging Face model cards: https://huggingface.co/docs/hub/model-cards
- QLoRA: Efficient Finetuning of Quantized LLMs: https://arxiv.org/abs/2305.14314
