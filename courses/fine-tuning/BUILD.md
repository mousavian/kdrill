# BUILD brief — `fine-tuning` course

**Queue check first:** open `courses/QUEUE.md`. Build the first course listed
there that still has a `BUILD.md`. If that is not this one, stop reading this
file and open that course's brief instead.

**Prerequisite:** the `llm-from-zero` course must already be built (its
`BUILD.md` gone and `kind: local` supported by the engine). If it is not, stop
and report that; do not build this course first.

You are building one kdrill course in a fresh session. Read first:
`hack/COURSE_AUTHORING.md` (including "Building from a BUILD.md brief"),
`STATUS.md`, `README.md`, and all of `courses/llm-from-zero/` (its lessons,
workspace layout, image, verify style and capstone). This course continues it.

## What the owner wants

Hands-on ML, the same way as `llm-from-zero`: the learner writes the
fine-tuning code themselves. Plain Python in the course container, no
Kubernetes (`kind: local`, same engine support, same workspace convention:
`~/kdrill-work/fine-tuning/`). A brief earlier version of this file described a
Kubernetes-workflow course; that is no longer wanted.

## Starting point

The base model is the learner's own GPT from the `llm-from-zero` capstone.
Setup must also work if they skipped it: provide a reference base checkpoint
(trained by the reference solution, produced deterministically by setup in a
few minutes, or committed if it is at most a few MB) and the same tokenizer.
Fine-tuning data is small and bundled or fetched with pinned checksums; the
offline rule from `llm-from-zero` applies.

Pick tasks where improvement is measurable on a tiny model, for example:
- **style**: adapt to a second author/genre (held-out loss on the target style);
- **format**: learn a fixed question → answer template from a few hundred
  examples (exact-match / format accuracy on held-out prompts);
- **preference**: prefer one kind of completion over another (win rate on a
  held-out set of pairs).

## Proposed lesson outline (a starting point — reorder, split, add; no cap)

Part A — what fine-tuning changes
1. Baseline: load the base model, measure it on the target task and on its
   original data. Write the evaluation harness the rest of the course uses.
2. Full fine-tuning: continue training all weights on the new data; learning
   rate and steps much smaller than pre-training; compare.
3. Catastrophic forgetting, measured; mitigations (lower LR, fewer steps,
   mixing in original data).
4. Freezing: train only the last block / head; trainable parameter counts.

Part B — building the dataset
5. Instruction / SFT data: write the formatter (prompt template, special
   tokens), clean and deduplicate examples, split by example.
6. Loss masking: train only on the answer tokens, not the prompt; verify by
   checking gradients are zero on prompt positions.
7. Data quality vs quantity: the same budget on noisy vs cleaned examples.

Part C — parameter-efficient fine-tuning, by hand
8. LoRA from scratch: a wrapper with low-rank A/B matrices on the attention
   projections, scaling by alpha/r, frozen base; trainable parameter count and
   adapter file size.
9. Rank and alpha: a small sweep; smallest rank that reaches the target.
10. Which layers to adapt: attention only vs attention + MLP.
11. Merging: fold the adapter into the weights; outputs identical before and
    after (verify checks numerically); when to keep adapters separate.
12. Several adapters on one base: switch per request; compare tasks.
13. Quantisation basics: int8 weights for the frozen base written by hand,
    memory saved and quality lost; the idea behind QLoRA.

Part D — preferences and evaluation
14. Preference data: chosen / rejected pairs.
15. DPO from scratch: the loss written by hand, a reference model, beta;
    win rate on held-out pairs.
16. Evaluation that you can trust: held-out sets, contamination checks
    (n-gram overlap between fine-tuning data and eval), seeds and variance.
17. Capstone: a new small task of the learner's choice: build the dataset,
    choose full vs LoRA, tune, evaluate against base, write a model card with
    the numbers.

## How verify works

As in `llm-from-zero`: hidden pytest tests in the course container against the
learner's workspace, numeric checks (LoRA merge equality, masked-gradient
zeros, DPO loss on known inputs), and outcome checks from short runs that
verify starts itself with fixed seeds and loose thresholds. Guard against
cheats: using `peft`/`trl` or other fine-tuning libraries (check imports),
training on the evaluation set, editing result files, copying the base as the
"tuned" model.

## Done means

Every lesson passes the full test cycle in `hack/COURSE_AUTHORING.md` (cluster
stopped, temporary `KDRILL_WORK`/`KDRILL_STATE_DIR`); STATUS.md and README.md
updated; this file deleted; the course removed from `courses/QUEUE.md`;
committed and pushed to `main`.
