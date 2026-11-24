#!/usr/bin/env bash
# Regenerate pylib/kdlib/data/clean_*.txt.gz from the reference solutions (needs docker + the image).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
for l in 03-clean 04-dedup 05-split; do cp "$here"/lessons/$l/solution/*.py "$tmp/"; done
cp "$here/hack/make_bundle.py" "$tmp/"
docker run --rm -v "$tmp:/work" -v "$here/pylib:/kdlib" -v "$here/pylib/kdlib/data:/out" -w /work \
  -e PYTHONPATH=/work:/kdlib kdrill.local/ml-dev:0.1.0 python3 make_bundle.py /out
rm -rf "$tmp"
