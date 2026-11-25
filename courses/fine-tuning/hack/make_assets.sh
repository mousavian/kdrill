#!/usr/bin/env bash
# Regenerate the committed assets of this course from the code (needs docker and the ml-dev image):
#   pylib/kdlib/data/*.jsonl, facts.json     the task files (hack/make_tasks.py, seeds in kdlib/tasks.py)
#   pylib/kdlib/data/ref_base.pt             the reference base model (hack/make_base.py, about 3 minutes on 4 CPUs)
#   pylib/kdlib/data/ref_sft.pt              the reference SFT model for DPO (hack/make_sft.py, 20 s)
# The Alice text (alice_*.txt.gz) comes from hack/make_alice.py and the pinned file in data/SOURCES.md (not rerun here).
# Training is not bit-reproducible across CPUs, so a regenerated model can differ in the last digits; the lessons'
# thresholds are loose for that reason. Re-run hack/regression.sh after replacing a model.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
img=kdrill.local/ml-dev:0.1.0
run() { docker run --rm --user "$(id -u):$(id -g)" --cpus "${CPUS:-4}" -v "$here:/ft" -v "$here/pylib:/kdlib:ro" -w /ft \
  -e HOME=/tmp -e OMP_NUM_THREADS="${CPUS:-4}" -e PYTHONPATH=/kdlib "$img" python3 "$@"; }
run hack/make_tasks.py pylib/kdlib/data
tmp="$(mktemp -d)"; chmod 777 "$tmp"
docker run --rm --user "$(id -u):$(id -g)" --cpus "${CPUS:-4}" -v "$here:/ft:ro" -v "$here/pylib:/kdlib:ro" -v "$tmp:/out" -w /ft \
  -e HOME=/tmp -e OMP_NUM_THREADS="${CPUS:-4}" -e PYTHONPATH=/kdlib "$img" python3 hack/make_base.py /out 2500
cp "$tmp/ref_base.pt" "$here/pylib/kdlib/data/ref_base.pt"
docker run --rm --user "$(id -u):$(id -g)" --cpus 2 -v "$here:/ft:ro" -v "$here/pylib:/kdlib:ro" -v "$tmp:/out" -w /ft \
  -e HOME=/tmp -e PYTHONPATH=/kdlib "$img" python3 hack/make_sft.py /out
cp "$tmp/ref_sft.pt" "$here/pylib/kdlib/data/ref_sft.pt"
rm -rf "$tmp"
