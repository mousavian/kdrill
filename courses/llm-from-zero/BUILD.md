# BUILD brief — `llm-from-zero` course

**Queue check first:** open `courses/QUEUE.md`. Build the first course listed
there that still has a `BUILD.md`. If that is not this one, stop reading this
file and open that course's brief instead.

You are building one kdrill course in a fresh session. Read, in this order,
before writing anything:

1. `hack/COURSE_AUTHORING.md` — layout, quality bar, test cycle, and the section
   "Building from a BUILD.md brief" (your permissions and hand-off).
2. `DESIGN.md`, `README.md`, `STATUS.md`, `base/lib/common.sh`, `base/lib/lesson.mk`,
   `internal/engine/` (you will extend it), `base/images/ml-tiny/` (you will reuse
   or extend it).
3. `courses/training/` briefly: it already exists and teaches the *platform* side
   (running training as Kubernetes Jobs). This course is the other half.

## What the owner wants (in their words, paraphrased)

"Learn how to train on data and build my own model, from zero: gathering data,
cleaning it up, etc., all the way." The existing `training` course was not
this: there the model is ready-made and the learner only writes Kubernetes
objects. In **this** course the learner writes the ML code: the data pipeline,
the tokenizer, the model, the backward pass, the training loop, the evaluation.

Decisions the owner made (do not reopen them):

- **Keep both courses.** Rename the existing `training` course to
  `training-platform` (step 0 below). The new course is `llm-from-zero`.
- **Depth: hand-built first, then PyTorch.** The early model lessons use plain
  Python / numpy with gradients written by hand (a counting bigram model, a tiny
  scalar autograd engine, a neural bigram, an MLP language model), so every
  gradient is visible. Then the course switches to PyTorch for the transformer.
  This is the path of Karpathy's "Neural Networks: Zero to Hero"; follow its
  spirit, write everything yourself (no copied code, nothing that recreates his
  notebooks verbatim), and cite it in Read more.
- **Plain Python, no Kubernetes.** Lessons run Python in a container on the
  learner's Mac. No cluster is needed for this course (and the learner should
  stop it to free memory). `kdrill` still sets up, verifies, resets and tracks
  progress exactly as for other courses.

## Step 0 — rename `training` to `training-platform`

- Move `courses/training` → `courses/training-platform`; fix every path,
  lesson label (`training.*` → `training-platform.*`), cleanup selector,
  README/STATUS/DESIGN mention, and cross-course reference.
- The owner **has progress** in `training` in `~/.kdrill/state.json` on their Mac,
  which this session cannot touch. Add a small engine feature so it carries over:
  `course.yaml` may list `formerly: [training]`; when state is loaded, progress,
  started-course and active-lesson entries under a former id move to the new id
  (and are saved). Unit-test it in `internal/state` or `internal/engine`.
- Update its title/description to say clearly that it is about running training
  on Kubernetes, and point to `llm-from-zero` for building a model.
- Run two of its lessons after the rename to prove nothing broke.

## Step 1 — engine support for `kind: local`

A lesson (or course) with `kind: local` needs no cluster:

- `start`, `verify`, `reset`, `cleanup`, `next`, `hint`, `status` work with the
  cluster stopped or absent; no namespaces, no taint changes, no kubectl.
- **Workspace.** The learner's code lives in a per-course workspace,
  `~/kdrill-work/<course>/` (override with `KDRILL_WORK`), not in the repo. Lessons
  build on each other, so the workspace persists across lessons. Lesson setup
  copies the lesson's `starter/` files into the workspace **only if they are not
  already there**, and never overwrites the learner's work. `reset` restores just
  that lesson's starter files after moving the learner's versions to
  `~/kdrill-work/<course>/.backup/<timestamp>/`. `cleanup` removes nothing the
  learner wrote. The workspace path is printed by `start`, `show` and `status`.
- **Running code.** Add `kdrill py <file.py> [args]` (and `make py F=...` in lesson
  folders): runs Python in the course image with the workspace mounted at
  `/work`, the course's data cache mounted read-only where lessons need it,
  `--memory` and `--cpus` limits from the profile (lite: about 1.5 GB, 2 CPUs),
  and no network unless the lesson declares it. Also `kdrill py` with no file
  opens an interactive Python shell in the same container.
- Scripts get `KDRILL_WORK` (host path) in their environment. Verify scripts run
  tests in the same container (see "How verify works").
- `kdrill doctor` and `status` stay accurate for local courses (cluster may be
  stopped); `status` shows the workspace for the active local lesson.
- Keep the change minimal, tested (`make test`), and re-run one lesson of an
  existing cluster course afterwards.

## Step 2 — the course image

Reuse `base/images/ml-tiny` if it fits; otherwise add `base/images/ml-dev`
(Python, numpy, CPU PyTorch arm64+amd64, pytest, tqdm, matplotlib for saved
plots only; no Jupyter requirement). Built locally by a component or by course
setup, never pushed. The course runs without a cluster, so the image is built
with plain `docker build` and used with `docker run`; no `k3d image import`.

## Data

- Lesson 01 is about **gathering data for real**, so it needs the internet:
  public-domain books from Project Gutenberg (and optionally a small slice of
  Wikipedia via its API). Pin the exact URLs and record sha256 sums; the learner
  writes the fetcher (polite: rate limit, user agent without personal data,
  respect the site's terms; Gutenberg asks bulk users to use mirrors — follow
  its robot/mirror guidance).
- Every later lesson must also work **offline** from a cache
  (`~/.cache/kdrill/llm-from-zero/`): if the learner's fetch fails or is skipped,
  setup provides the pinned raw files from a verified download (or, failing
  that, a small bundled public-domain corpus in the repo, a few hundred KB).
- Pick a corpus the learner will enjoy watching a model imitate (one author or
  genre), 2–10 MB raw text: big enough to need cleaning, small enough for CPU.

## Proposed lesson outline (a starting point — reorder, split, add; no cap)

Part A — data (the part the owner explicitly asked for)
1. Gather: write a fetcher for a list of Gutenberg books; retries, caching,
   checksums, a manifest (source, licence, date, size).
2. Look before you clean: character inventory, encodings, line endings, sizes,
   oddities; write a short data report script.
3. Clean: strip Gutenberg headers/footers and licence text, normalise unicode
   and whitespace, remove front matter / tables of contents; tests on tricky
   samples the learner has not seen.
4. Filter and deduplicate: exact and near-duplicate paragraphs (hashing /
   shingles), length and junk filters; measure what was removed and why.
5. Split without leakage: train / validation / test by document, not by line;
   why random line splits lie.
6. A data card: what is in the dataset, licences, known biases, stats.

Part B — tokenization
7. Character tokenizer: vocab, encode/decode round trip, unknown characters.
8. Byte-pair encoding from scratch: train merges on the training split,
   encode/decode, special tokens.
9. Vocabulary size trade-offs: tokens per word, sequence length, rare merges;
   pick a size and justify it with numbers.

Part C — models by hand (numpy / pure Python, no PyTorch allowed)
10. Counting bigram model: counts → probabilities, sampling, smoothing.
11. Loss: negative log-likelihood and perplexity on validation; why a model that
    memorises training data scores badly.
12. Autograd from scratch: a scalar `Value` with backward for + * tanh exp log
    pow; gradient-check against finite differences.
13. A neural bigram: one weight matrix, softmax, cross-entropy, gradients
    derived by hand in numpy, gradient descent until it matches the counting model.
14. MLP language model: embeddings, context window, hidden layer, manual
    backprop through every layer (verified against numeric gradients).
15. Training dynamics: initialisation, learning-rate search, activation and
    gradient statistics, why normalisation helps.

Part D — a transformer in PyTorch
16. From numpy to PyTorch: port the MLP model; autograd gives the same gradients
    as the hand-written ones (verify compares them).
17. Batches and the training loop properly: data loader over token ids, AdamW,
    evaluation loop, logging.
18. Self-attention: one causal head written by hand; masking; shapes.
19. The transformer block: multi-head attention, feed-forward, residuals,
    layer norm; parameter count by hand vs by code.
20. The full GPT: position embeddings, stacked blocks, weight tying; overfit a
    single batch as a sanity check.
21. Train it for real: LR warm-up and cosine decay, gradient clipping,
    checkpoint and resume, a run that fits in a few minutes on CPU.
22. Overfitting and regularisation: dropout, weight decay, early stopping on
    validation loss.
23. Generation: temperature, top-k / top-p, repetition; what changes in samples.
24. Small scaling experiment: model size vs data vs steps at a fixed compute
    budget; plot loss curves; what scaling laws say.
25. Evaluation beyond loss: test-set perplexity, a few targeted probes, human
    side-by-side of samples; why benchmarks are hard.
26. Capstone: a new corpus of the learner's choice through the whole pipeline
    (gather → clean → tokenize → train → evaluate), ending in a model card and
    a checkpoint that the `fine-tuning` course will start from.

## How lessons and verify work

- Each lesson ships `starter/` files with a fixed interface (functions/classes
  with docstrings and `TODO`), a README task, hints and a reference solution.
- `verify` runs hidden **pytest** tests in the course container against the
  learner's workspace: behaviour on inputs they have not seen (tricky text for
  cleaners, round trips for tokenizers, numeric gradient checks for backprop,
  shape and causality checks for attention), plus outcome checks where training
  is the point (validation loss below a loose, seed-fixed threshold reached by a
  short run that verify itself starts, so a pasted number cannot pass).
- Guard against cheats: importing torch in the numpy lessons (check imports),
  calling library implementations instead of writing them (e.g. `nn.MultiheadAttention`,
  `torch.nn.functional.scaled_dot_product_attention`, existing tokenizers),
  training on validation data, hard-coding expected outputs.
- verify output names the failing behaviour, never the answer.
- Keep each verify under ~60 s on 2 CPUs; say in the README when a step trains
  for longer and give the learner a `make py F=train.py` command for the long run.
- Reference solutions must pass every lesson's tests in order, starting from an
  empty workspace, in one regression run.

## Testing

Same cycle as `hack/COURSE_AUTHORING.md` (fails on starter → passes with
solution → one cheat rejected → reset keeps the learner's files in `.backup`),
with the cluster stopped. Use a temporary `KDRILL_WORK` and `KDRILL_STATE_DIR`
for tests, never the owner's. Also run a cluster course lesson afterwards to
prove the engine change did not break the cluster path.

## Done means

Step 0 rename done and tested; `kind: local` in the engine with tests; every
lesson passes the full cycle; STATUS.md, README.md and DESIGN.md updated
(course table, decisions, what needs the internet, image size, run times);
this file deleted; the course removed from `courses/QUEUE.md`; committed and
pushed to `main`.
