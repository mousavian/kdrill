# Shared lab images

Images that more than one course needs and that must be built locally (they are
never pushed anywhere). Each lives in its own folder with a `Dockerfile` and a
`build.sh` that builds for the host architecture, tags `kdrill.local/<name>:<version>`
and imports it into the cluster with `k3d image import -c "$KDRILL_CLUSTER"`.
`build.sh` must be idempotent: skip the build when the tag already exists in
Docker, and always (re)import, because a nuked cluster loses imported images.

Planned (created by whichever of the training / fine-tuning / inference /
kubeflow courses is built first; later courses reuse it, never fork it):

- `ml-tiny` — Python slim + CPU-only PyTorch (arm64 wheel) + numpy + a tiny
  character-level GPT (`model.py`, `train.py`, `sample.py`, `serve.py`) and a small
  bundled text corpus, so nothing is downloaded at lesson time. Target: under
  ~900 MB on disk, under ~600 MB RSS while training the default model.
