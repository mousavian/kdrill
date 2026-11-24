# Course build queue

The scheduled course builder (and anyone building a course from a `BUILD.md`)
takes the **first** course in this list that still has a `BUILD.md`, builds
only that one, then removes it from this list in the same commit.

1. `llm-from-zero` — build a language model from zero: data, tokenizer,
   hand-written backprop, a GPT in PyTorch. Also renames `training` to
   `training-platform` and adds `kind: local` to the engine.
2. `fine-tuning` — hands-on fine-tuning of that model (needs 1).
3. `kubeflow` — Kubeflow projects as separate small courses.

Built courses have no `BUILD.md` and are not listed here.
