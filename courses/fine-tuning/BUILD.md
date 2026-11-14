# BUILD brief — `fine-tuning` course

You are building one kdrill course in a fresh session. Read, in this order,
before writing anything:

1. `hack/COURSE_AUTHORING.md` — layout, limits, quality bar, test cycle, and the
   section "Building from a BUILD.md brief" (your permissions and hand-off).
2. `DESIGN.md`, `README.md`, `STATUS.md`, `base/lib/common.sh`, `base/images/README.md`.
3. `courses/training/` if it has been built (lessons, `lib.sh`, and the
   `ml-tiny` image under `base/images/ml-tiny/`). This course continues from it
   but must also work when the learner skipped it.
4. `courses/inference/` if built — the serving lessons here should use the same
   server and client helpers.

## Goal

A learner who finishes understands what fine-tuning is mechanically and can run
it as a Kubernetes workflow: take a base model, prepare a dataset, train a LoRA
adapter as a Job, evaluate it against the base, version the artifact, and serve
base and adapters side by side. The model is a tiny character-level GPT on CPU
so every run takes a minute or two; READMEs say what changes with a real LLM,
PEFT/Transformers and GPUs.

- Directory: `courses/fine-tuning`, `kind: real-compute`,
  `requires: [training]` (informational).
- No lesson cap.

## Design decisions already made (change only with a recorded reason)

- **No big downloads.** The base model is the tiny GPT from `ml-tiny`. A
  pretrained base checkpoint must be available without running the training
  course: either committed to the repo (a few MB at most) or produced
  deterministically during the image build. Check size before committing.
- **LoRA is written by hand** in the image (`lora.py`, roughly 50 lines: low-rank
  A/B matrices on the attention projections, rank, alpha, merge/unmerge). The
  learner reads it in the first LoRA lesson. Seeing the parameter count drop is
  part of the lesson.
- **Datasets are small bundled text files** in clearly different styles (for
  example the base is trained on one corpus and adapters on two others), so
  "did fine-tuning work" is measurable: loss on the target style falls well
  below the base model's loss on it. Pick corpora with clear licences (public
  domain) and keep them small.
- **Evaluation writes JSON** (`eval.json`: loss/perplexity per dataset, per
  model) that verify reads. Fixed seeds, loose thresholds.
- Optional `full` profile lesson using Hugging Face `peft` on a very small real
  model is allowed only if it fits in memory and is clearly marked as needing
  internet. The `lite` path must never download.

## Machine constraints

8 GB Mac, Docker VM 4 GB, one k3s node, CPU only, arm64. A fine-tune run:
1–2 minutes, under ~600 MB RSS. Storage is `local-path` PVCs. Reuse the
`ml-tiny-image` component; extend the image (bump its version) rather than
making a second one, and re-test one lesson of each course that already uses it.

## Proposed lesson outline (a starting point — reorder, split, add)

Part A — what fine-tuning changes
1. Baseline: load the base checkpoint in a Job, sample text, evaluate on the base
   corpus and on the target corpus. Starts with a Job that can't find the model
   (wrong mount/path).
2. Full fine-tune: continue training all weights on the target data; evaluate.
   See the cost: a full copy of the model per task, and the base corpus loss gets worse.
3. Catastrophic forgetting, measured; mitigations (lower LR, fewer steps, mixed data).
4. Freezing layers: train only the last block / head; compare trainable
   parameter counts and results.

Part B — LoRA
5. LoRA by hand: read `lora.py`, run an adapter fine-tune, compare trainable
   parameters and artifact size (adapter is kilobytes vs the full checkpoint).
6. Rank and alpha: an Indexed Job sweep over rank; pick the smallest rank that
   meets the target loss.
7. Which modules to adapt (attention only vs attention + MLP).
8. Learning rate and step count for adapters; over-fitting a tiny dataset and
   spotting it with a held-out split.
9. Merge vs keep separate: merged weights for a single-task server; adapters for many tasks.

Part C — data
10. Dataset preparation as its own Job: clean, split train/validation, write to a
    PVC with a manifest (hash, sizes). The tune Job must refuse a dataset
    without a validation split.
11. Dataset versioning: two dataset versions; the adapter records which one it
    was trained on (metadata file next to the weights).

Part D — the workflow on Kubernetes
12. The fine-tune Job done properly: resources, checkpoint/resume (short recap of
    the training course mechanics applied here), failure policy.
13. Evaluation as a gate: an eval Job that exits non-zero when the adapter is
    not better than base by a margin; promotion only after it passes.
14. Artifacts and versions: a simple registry layout on a PVC or MinIO
    (`models/<name>/<version>/{adapter.pt,meta.json,eval.json}`), a "promoted"
    pointer, and rollback to the previous version.
15. Chain it: prep → tune → eval → promote as one pipeline using plain
    Kubernetes (init containers or a JobSet with ordered jobs — whichever is
    clean on the versions installed). Note where Kubeflow Pipelines / Argo fit.
16. Many adapters at once: tune two adapters in parallel under a Kueue quota.

Part E — serving the result
17. Serve the base model with one adapter loaded at startup (a Deployment of
    the tiny server; completions endpoint).
18. Multi-adapter serving: one base in memory, adapter chosen per request by
    model name; add a new adapter without restarting (reload on file change or
    an admin call), verify both answer in their own style.
19. Compare base vs tuned behind one Service (A/B by header or weight) and roll
    back by moving the "promoted" pointer.
20. Capstone: given a new small dataset, deliver a promoted adapter that passes
    the eval gate and is being served, with a planted fault in the pipeline.

## How verify should work

- Read results, not intentions: `eval.json` numbers (tuned loss on target below
  base loss by a margin; base-corpus loss not degraded beyond a bound where the
  lesson is about forgetting), adapter file size and trainable-parameter count
  from `meta.json`, Job exit codes, which adapter answered a request (the server
  returns the adapter name/version in a response header or field).
- Guard against cheats: evaluating on training data, copying the base as the
  "adapter", editing `eval.json` by hand (have the eval Job sign results with a
  hash of the weights it loaded, or re-run a short eval inside verify), raising
  the threshold instead of improving the adapter.
- Runs take a minute or two: README states the wait; verify polls with a clear message.

## Known traps

- Determinism on CPU: set seeds and thread count; thresholds must survive
  small run-to-run differences. Run each lesson three times before trusting it.
- Character-level models learn style quickly but generalise poorly; choose
  metrics (held-out loss) that actually move.
- Keep checkpoint format stable between `training` and this course; if
  `training` is rebuilt later it must still produce a compatible base.
- Real pods must never land on KWOK fake nodes left by other courses.

## Check upstream before relying on it

Only the pieces you add beyond plain Kubernetes: JobSet ordering features if
used (startup policy / dependsOn names and versions), Kueue version in
`base/components/kueue`, MinIO tag if used, and — for the optional `full`
lesson — `peft` / `transformers` versions and a model small enough to fit.

## Done means

Every lesson passes the full test cycle in `hack/COURSE_AUTHORING.md`; course
stop/start is clean; image changes are re-tested against other courses;
footprint written in STATUS.md; this file is deleted; committed to `main`.
