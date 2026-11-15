# Shared lab images

Images that more than one course needs and that must be built locally (they are
never pushed anywhere). Each lives in its own folder with a `Dockerfile` and a
`build.sh` that builds for the host architecture, tags `kdrill.local/<name>:<version>`
and imports it into the cluster with `k3d image import -c "$KDRILL_CLUSTER"`.
`build.sh` must be idempotent: skip the build when the tag already exists in
Docker, and always (re)import, because a nuked cluster loses imported images.

## ml-tiny (`kdrill.local/ml-tiny:0.1.0`)

Created by the training course; later courses (fine-tuning, kubeflow) reuse
it and extend it without breaking it (bump `ML_TINY_VERSION` in `build.sh`
when the contents change, because `build.sh` skips the build when the tag
exists). The `ml-tiny-image` component runs `build.sh` on `course start`.

- `python:3.13-slim` (pinned by digest), PyTorch 2.15.0+cpu from PyTorch's CPU
  wheel index (it has both linux/amd64 and linux/arm64 wheels; the plain PyPI
  Linux wheels pull in several GB of CUDA libraries on both architectures),
  numpy, boto3. Test binaries and headers are removed from the torch wheel.
- `/opt/ml-tiny/app`: `model.py` (character-level GPT, about 354,000
  parameters by default), `train.py`, `sample.py`, `prepare.py`, `serve.py`,
  `mlt.py` (inspection tool used by verify scripts), `store.py` (directory or
  `s3://` storage). Each has a wrapper on the PATH: `train`, `sample`,
  `prepare`, `serve`, `mlt`. `train --help` lists every flag and the
  environment variable that sets it.
- Corpus: Tiny Shakespeare (1.1 MB, public domain), downloaded at build time
  with a pinned sha256, as plain text in `/opt/ml-tiny/data/` and gzipped in
  `/opt/ml-tiny/datasets/`. Nothing is downloaded at lesson time.
- Measured (amd64 build, Linux host): 232 MB compressed, about 810 MB unpacked.
  The default run (2000 steps, batch 32) takes 93 s on 2 CPUs and peaks at
  400 MB RSS; batch 512 needs about 1.1 GB.
- Behind a TLS-inspecting proxy: `KDRILL_BUILD_CA=/path/ca.pem` passes an extra
  CA bundle to pip as a build secret; `HTTPS_PROXY` is passed to the build.
