# kdrill

A local, hands-on Kubernetes practice lab. Topics are **courses**, each a
sequence of **lessons**: you get a goal and a prepared cluster, work with your
own `kubectl`, and `kdrill verify` tells you exactly what is still wrong.
Runs on one small k3d cluster (fake KWOK nodes for scheduling and scale
topics, real containers and traffic for the gateway and service-mesh courses,
real tiny models for the inference and training-platform courses, and a
no-cluster Python course, llm-from-zero, where you build a language model
yourself), sized for an 8 GB laptop. No cloud account, no cloud bill, no GPU.

Website: [kdrill.5xx.tech](https://kdrill.5xx.tech/). How it is built:
[DESIGN.md](DESIGN.md). What is done and what is next: [STATUS.md](STATUS.md).

## Courses

| Course | Lessons | Runs on | What you practise |
|---|---|---|---|
| `k8s-scheduling` | 6 | simulated nodes | Why pods go Pending: requests, taints, spread, priority, GPUs. Start here. |
| `gpu-scheduling` | 12 | simulated nodes | Bin-packing, time-slicing, MIG, quotas, Kueue, gang admission, DRA. |
| `karpenter` | 12 | simulated nodes | Real Karpenter launching fake nodes: NodePools, spot, consolidation, drift. |
| `kyverno` | 13 | simulated nodes | Admission policy as code: validate, mutate, generate, exceptions, CEL. |
| `envoy` | 38 | real traffic | Envoy from a config file to Envoy Gateway and the Gateway API. |
| `istio` | 14 | real traffic | Sidecars, canaries, mTLS, authorization, ambient mode. |
| `inference` | 26 | real model | Serve an LLM: probes, KEDA on queue depth, endpoint picking, GPU capacity. |
| `training-platform` | 20 | real model | Real PyTorch runs as Jobs: checkpoints, preemption, JobSet, Kueue. |
| `llm-from-zero` | 27 | Python, no cluster | Build a language model yourself: data, tokenizers, hand-written backprop, a GPT, training, evaluation. |

168 lessons in all. More courses are planned; see [courses/QUEUE.md](courses/QUEUE.md).

## Prerequisites

- Docker (Docker Desktop, OrbStack or Colima), with the VM given at least 3-4 GB
- [k3d](https://k3d.io) and `kubectl`: `brew install k3d kubectl`
- Go (to build the CLI, and to build Karpenter for the karpenter course)
- `helm` (needed by the kyverno and karpenter courses)
- `curl` and internet access for the istio course: it downloads the pinned
  `istioctl` into `~/.kdrill/bin` and the Gateway API CRDs, and pulls Istio's images
- internet access (once) for the inference course: its first `course start`
  downloads a 105 MB model file into `~/.kdrill/models` (checksum-verified) and
  pulls about 600 MB of images; `docker` must be able to build a `FROM scratch` image
- internet access (once) and `docker build` for the training-platform course: its first
  `course start` builds the shared image `kdrill.local/ml-tiny` (CPU-only
  PyTorch, about 250 MB download, 1-3 minutes) for your machine's architecture
  and imports it into the cluster; behind a TLS-inspecting proxy, point
  `KDRILL_BUILD_CA` at the proxy's CA bundle
- the llm-from-zero course needs **only Docker** (no k3d, no cluster; stop the cluster to free
  memory): its first lesson builds `kdrill.local/ml-dev` (CPU-only PyTorch, about 300 MB
  download, 2-5 minutes) with a plain `docker build`, and lesson 01 downloads 4 MB of
  public-domain books from Project Gutenberg mirrors (checksum-verified; offline it falls back
  to a small bundled corpus)

## Quick start

```sh
git clone https://github.com/mousavian/kdrill
cd kdrill
make build                 # builds bin/kdrill (remembers where this repo lives)
make install               # optional: copy it to $(go env GOPATH)/bin
bin/kdrill doctor          # checks docker, memory, k3d, kubectl
bin/kdrill cluster up      # creates the k3d cluster "kdrill" + installs KWOK
bin/kdrill status          # cluster, context, components, active lesson, course progress
bin/kdrill start k8s-scheduling/01
```

Then loop: read the task, poke at the cluster with `kubectl`, and run

```sh
kdrill verify              # exit 0 when every check passes
kdrill hint                # progressive hints
kdrill solution            # the reference answer
kdrill reset               # start the lesson over
kdrill next                # clean up and start the next lesson
kdrill status              # where you are; `kdrill status <course>` lists its lessons
```

kdrill uses its own kubeconfig (`~/.kdrill/kubeconfig`) for everything it runs,
so it never touches another cluster. Your normal `kubectl` also works: the
context `k3d-kdrill` gets its default namespace set to the lesson's namespace.
`kdrill status` warns if your current context is a different cluster.

### Local courses (no cluster)

A course with `kind: local` (llm-from-zero) runs your own Python in a container. Your files live in
`~/kdrill-work/<course>/` (set `KDRILL_WORK` to move it); starting a lesson copies its starter
files there without overwriting your work, and `kdrill reset` saves your versions of that lesson's
files in `.backup/` before restoring the starter.

```sh
kdrill start llm-from-zero/01    # works with the cluster stopped or absent; builds the image the first time
kdrill py fetcher.py             # run a file from your workspace in the course container (/work)
kdrill py                        # an interactive Python shell in the same container
kdrill verify                    # hidden pytest tests against your workspace
```

`make py F=file.py` does the same from a lesson folder. `kdrill doctor` only requires Docker
while a local lesson is active.

### From inside a lesson folder

Each lesson has a one-line `Makefile`, so you can stay in the folder:

```sh
cd courses/k8s-scheduling/lessons/01-requests-and-pending
make          # list targets
make setup    # = kdrill start k8s-scheduling/01-requests-and-pending
make verify   # also: hint, reset, cleanup, solution, show, next
```

`verify`, `reset` and friends refuse to run if a different lesson is active.
Courses have a Makefile too (`make start | stop | lessons`).

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `KDRILL_HOME` | build-time path, else found by walking up | repo root (has `base/` and `courses/`) |
| `KDRILL_CLUSTER` | `kdrill` | k3d cluster name |
| `KDRILL_STATE_DIR` | `~/.kdrill` | `state.json` (progress) and `kubeconfig` |
| `KDRILL_WORK` | `~/kdrill-work` | workspace root of local courses (one folder per course) |
| `KDRILL_CACHE` | `~/.cache/kdrill` | download cache root of local courses |
| `KDRILL_DOCKER_ARGS` | – | extra `docker run` flags for `kdrill py` (for example `--network host`); a `--network` here replaces kdrill's |
| `KDRILL_CA` | – | CA bundle mounted into `kdrill py --net` containers (TLS-inspecting proxies) |

`kdrill profile lite|full` switches lesson sizing (default `lite`).

## Adding a course

A course is a folder of plain files, no recompiling:

```
courses/<course>/
  course.yaml        title, description, kind (sim|real-light|real-compute|local), components,
                     optional formerly: [old ids] (progress moves to this id), image/image_build (local)
  setup.sh           optional, runs on `course start`
  teardown.sh        optional, runs on `course stop`
  Makefile           include ../../base/lib/course.mk
  lessons/<NN-slug>/
    lesson.yaml      title, goal, concepts, optional kind / namespaces / timeout
    README.md  setup.sh  verify.sh  hints.md  solution/  [cleanup.sh]
    Makefile         include ../../../../base/lib/lesson.mk
```

Scripts get helpers from `base/lib/common.sh` (`fake_node`, `check`, `jp`, `kd_pytest`, ...).
Local courses ship `starter/`, `solution/` and hidden `tests/` per lesson instead of manifests.
Shared installs live in `base/components/<name>/{install,uninstall}.sh` and are
listed in `course.yaml`. Details and file formats: [DESIGN.md](DESIGN.md).

## Memory tips (8 GB machines)

- Give Docker about 4 GB; more starves macOS, less starves k3s.
- Work on one course at a time: `kdrill course stop <course>` removes its components.
- `kdrill cluster down` stops the cluster and frees its RAM; `up` resumes it.
- `kdrill cluster nuke` deletes the cluster (progress is kept).
- Close other k3d/kind clusters while practicing.
- OrbStack or Colima idle noticeably lighter than Docker Desktop.

## Development

`make test` runs unit tests, `make clean` removes `bin/`.

The landing page lives in [site/](site/) and is published to GitHub Pages by
`.github/workflows/pages.yml`.

## License

[MIT](LICENSE).
