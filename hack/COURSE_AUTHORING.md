# Authoring a kdrill course

Rules for whoever (human or agent) writes a new course. Read DESIGN.md, README.md,
STATUS.md and base/lib/common.sh first, then one existing course in full
(courses/gpu-scheduling for `sim`, courses/kyverno for admission-style checks).

## Shape

```
courses/<course>/
  course.yaml      title, description, kind, components: [...], requires: [...]
  Makefile         one line: include ../../base/lib/course.mk
  lib.sh           course-specific bash helpers (source "$KDRILL_HOME/courses/<course>/lib.sh")
  setup.sh / teardown.sh   optional, once per course
  lessons/NN-slug/
    lesson.yaml    title, goal, kind (optional), concepts, namespaces (default [drill]), timeout (default 180s)
    README.md      Concept / The situation / Your task / Useful commands / On a real cluster (where the lab differs) / Read more
    setup.sh verify.sh [cleanup.sh]
    hints.md       3 hints separated by lines that are exactly ---
    solution/      README.md + manifests
    manifests/     starting YAML
    Makefile       one line: include ../../../../base/lib/lesson.mk
base/components/<name>/install.sh, uninstall.sh   idempotent, pinned versions
base/components/<name>/check.sh   exit 0 when installed and healthy; on every lesson
                                  start kdrill reinstalls a component whose check fails
```

There is **no limit on the number of lessons**. Use as many as the topic needs to
be covered cleanly; one concept per lesson; lessons build on each other.

## Lesson kinds

- `sim` — the engine taints the real node `node-role.kubernetes.io/control-plane:NoSchedule`;
  workloads run on fake nodes from `fake_node` (no containers start).
- `real-light` / `real-compute` — the taint is removed; pods run as real containers on
  the single k3s node. Every image must be multi-arch (arm64), small, and pinned.

## Local courses (`kind: local`)

No cluster: lessons run the learner's Python in the course image (see `courses/llm-from-zero/`,
`base/images/ml-dev/`). Per lesson: `starter/` (interfaces with TODOs, copied to the workspace only
when absent), `solution/` (README + the same file names), hidden `tests/test_*.py` (pytest, run by
`kd_pytest` in verify.sh), `hints.md`, `setup.sh` (`llm_setup <mode>` seeds data), `lesson.yaml`
(`network: true` only where the lesson needs the internet). Rules: tests check behaviour on inputs
the learner has not seen and reject cheats (library imports in hand-written lessons, `nn.MultiheadAttention`,
training on validation data); verify output names the failing behaviour, never the answer; keep each
verify under about 60 s on 2 CPUs; the reference solutions must pass all lessons in order from an empty
workspace (`courses/llm-from-zero/hack/regression.sh`). Test with a temporary `KDRILL_WORK`,
`KDRILL_STATE_DIR` and `KDRILL_CACHE`; the cluster is not needed.

## Machine limits (design for these)

8 GB Apple Silicon Mac, Docker VM 4 GB, one k3s node (~0.6–1 GB by itself), system
bash 3.2 (no associative arrays / mapfile; careful with empty arrays under `set -u`).
Budget for a course's components plus a lesson's workloads: about 1.5 GB. Prefer the
leanest install profile, single replicas, small requests, short-lived workloads.
State the measured footprint in your report. k3s is started with traefik,
servicelb and metrics-server disabled; there is no load balancer — reach services
with `kubectl port-forward`, NodePort is not exposed to the host, or run a client
pod inside the cluster.

## Rules

- Do not edit cmd/, internal/, base/lib/*, hack/, or other courses. Need an engine
  or common.sh change? Work around it and report it.
- Components that must survive sim lessons need a toleration for the control-plane
  taint and must not be able to land on fake nodes.
- Cluster-scoped objects created by setup.sh carry the label key `kdrill.dev/lesson`
  (value "$KDRILL_LESSON"); objects the learner creates cluster-scoped need a
  cleanup.sh. Cleanup must never hang (finalizers, webhooks with no backend).
- `course stop` must remove everything the components installed (CRDs, webhooks,
  namespaces, cluster roles) and a later `course start` must reinstall cleanly.
- Scripts get: KUBECONFIG, KDRILL_HOME, KDRILL_PHASE, KDRILL_LESSON,
  KDRILL_LESSON_DIR, KDRILL_NS, KDRILL_PROFILE (lite|full), KDRILL_CLUSTER,
  KDRILL_STATE_DIR. Tools downloaded for a lesson go under $KDRILL_STATE_DIR/bin,
  pinned and checksum-verified — never installed system-wide.

## Quality bar

- Accurate for the versions you pin. Don't invent API fields: `kubectl explain`
  against the live CRDs, apply every manifest for real. Read-more links are real
  official docs and return HTTP 200.
- Concept sections 150–350 words, plain language, practical.
- The README states every rule verify enforces. No hidden rules.
- Each lesson starts broken/incomplete with a clear, checkable goal. verify tests
  BEHAVIOUR (what actually happens: traffic, admission, placement, metrics) and the
  mechanism where the concept demands it, plus guard checks against cheats. No
  dependence on pod names or tight timing; poll briefly where controllers need time.
- A passing verify should take under ~20 s; say so in the README when a step
  needs longer.

## Testing (required, with evidence)

Use your own cluster, never `kdrill` or `~/.kdrill`:

    export KDRILL_CLUSTER=kdrill-dev KDRILL_STATE_DIR=$HOME/.kdrill-dev
    make build && bin/kdrill cluster up      # run again if the node wait fails once

For EVERY lesson, through bin/kdrill: start → verify FAILS (exit 1) on the intended
checks → apply the reference solution exactly as written → verify PASSES (exit 0)
→ reset, try one plausible cheat, verify rejects it → cleanup leaves nothing behind.
Then a final regression over all lessons in order after the last edit, plus
`course stop` / `course start`, plus one lesson of another course after `course stop`.

When finished: `bin/kdrill cluster nuke`, `rm -rf $HOME/.kdrill-dev`,
`kubectl config use-context k3d-kdrill` (ignore failure). No git commands.

## Report

Lesson list (one line each); components, versions, footprint; per-lesson evidence
table (failed first on / time to pass / cheat rejected); anything infeasible,
flaky, skipped, or different from a real cluster; engine/common.sh changes wanted;
anything left on the machine; confirmation of teardown.

## Building from a BUILD.md brief (fresh session)

Which course: the first one in `courses/QUEUE.md` that still has a `BUILD.md`.
When it is built, remove it from the queue and push `main` (the scheduled
builder runs in the cloud and only sees what is pushed).

Some course directories contain only a `BUILD.md`. That file is the brief for
building that course in a brand-new session with no earlier context. If you were
pointed at one, you are the owner of the build, not a subagent, so these rules
replace the stricter ones above:

- You may run git. This folder is the repo root (github.com/mousavian/kdrill).
  Commit straight to `main` (the owner has said this is fine), staging only the
  paths you changed. Never `git add -A`.
- You may make small, tested changes to `base/lib/common.sh`, `internal/`, `cmd/`
  when a course needs them (run `make test`, rebuild, re-run one lesson of an
  older course to prove nothing broke). Keep them minimal and list them in STATUS.md.
- Still test on your own cluster (`kdrill-dev`), then spot-check two or three
  lessons on the main `kdrill` cluster through `bin/kdrill`, and remove the test
  progress from `~/.kdrill/state.json` afterwards.
- Build one course per session. Do not start a second course.
- Work from the brief, but verify every version, image and API field against the
  real upstream release before relying on it. The brief was written from memory
  and marks what must be checked. If something in it turns out to be wrong or does
  not fit in memory, choose the closest working alternative and record the change.
- Heavy work can go to subagents (cheaper models for mechanical work), one at a
  time; never run two cluster-using agents at once on this machine.
- When done: delete `BUILD.md` from the course directory, update `STATUS.md`
  (course table, decisions needing review, machine installs, known gaps), update
  the course list in `README.md` if it has one, commit, and stop both clusters
  (`bin/kdrill cluster down`; `kdrill-dev` nuked).
