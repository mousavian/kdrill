# kdrill

A local, hands-on Kubernetes practice lab. Topics are **courses**, each a
sequence of **lessons**: you get a goal and a prepared cluster, work with your
own `kubectl`, and `kdrill verify` tells you exactly what is still wrong.
Runs on one small k3d cluster (fake KWOK nodes for scheduling and scale
topics, real containers and traffic for the service-mesh course), sized for
an 8 GB laptop. See [DESIGN.md](DESIGN.md) for the full plan.

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

## Quick start

```sh
make build                 # builds bin/kdrill (remembers where this repo lives)
make install               # optional: copy it to $(go env GOPATH)/bin
bin/kdrill doctor          # checks docker, memory, k3d, kubectl
bin/kdrill cluster up      # creates the k3d cluster "kdrill" + installs KWOK
bin/kdrill courses
bin/kdrill start k8s-scheduling/01
```

Then loop: read the task, poke at the cluster with `kubectl`, and run

```sh
kdrill verify              # exit 0 when every check passes
kdrill hint                # progressive hints
kdrill solution            # the reference answer
kdrill reset               # start the lesson over
kdrill next                # clean up and start the next lesson
```

kdrill uses its own kubeconfig (`~/.kdrill/kubeconfig`) for everything it runs,
so it never touches another cluster. Your normal `kubectl` also works: the
context `k3d-kdrill` gets its default namespace set to the lesson's namespace.
`kdrill status` warns if your current context is a different cluster.

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

`kdrill profile lite|full` switches lesson sizing (default `lite`).

## Adding a course

A course is a folder of plain files, no recompiling:

```
courses/<course>/
  course.yaml        title, description, kind (sim|real-light|real-compute), components
  setup.sh           optional, runs on `course start`
  teardown.sh        optional, runs on `course stop`
  Makefile           include ../../base/lib/course.mk
  lessons/<NN-slug>/
    lesson.yaml      title, goal, concepts, optional kind / namespaces / timeout
    README.md  setup.sh  verify.sh  hints.md  solution/  [cleanup.sh]
    Makefile         include ../../../../base/lib/lesson.mk
```

Scripts get helpers from `base/lib/common.sh` (`fake_node`, `check`, `jp`, ...).
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
