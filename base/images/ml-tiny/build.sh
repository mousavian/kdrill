#!/usr/bin/env bash
# Build kdrill.local/ml-tiny for the host architecture and import it into the
# k3d cluster. Idempotent: the build is skipped when the tag already exists in
# Docker; the import always runs (a nuked cluster loses imported images).
#
#   KDRILL_CLUSTER     cluster to import into (default kdrill)
#   ML_TINY_NO_IMPORT  set to 1 to only build
#   KDRILL_BUILD_CA    optional CA bundle for pip behind a TLS-inspecting proxy
#                      (HTTPS_PROXY, if set, is passed to the build as well)
set -euo pipefail
ML_TINY_VERSION=0.1.0
IMAGE="kdrill.local/ml-tiny:${ML_TINY_VERSION}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "  building $IMAGE (first time only: downloads about 250 MB, 2-5 minutes)..."
  args=(build -t "$IMAGE")
  if [[ -n "${KDRILL_BUILD_CA:-}" ]]; then args+=(--secret "id=ca,src=$KDRILL_BUILD_CA"); fi
  if [[ -n "${HTTPS_PROXY:-}" ]]; then args+=(--network host --build-arg "HTTPS_PROXY=$HTTPS_PROXY"); fi
  DOCKER_BUILDKIT=1 docker "${args[@]}" "$here" >/tmp/ml-tiny-build.$$.log 2>&1 \
    || { tail -n 30 /tmp/ml-tiny-build.$$.log >&2; rm -f /tmp/ml-tiny-build.$$.log; echo "error: building $IMAGE failed" >&2; exit 1; }
  rm -f /tmp/ml-tiny-build.$$.log
fi
if [[ "${ML_TINY_NO_IMPORT:-}" != 1 ]]; then
  echo "  importing $IMAGE into cluster ${KDRILL_CLUSTER:-kdrill}..."
  k3d image import -c "${KDRILL_CLUSTER:-kdrill}" "$IMAGE" >/dev/null 2>&1 \
    || { echo "error: could not import $IMAGE into the cluster" >&2; exit 1; }
fi
echo "$IMAGE"
