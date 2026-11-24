#!/usr/bin/env bash
# Build kdrill.local/ml-dev for the host architecture with plain `docker build`.
# Idempotent: skipped when the tag already exists. No cluster involved.
#
#   KDRILL_BUILD_CA    optional CA bundle for pip behind a TLS-inspecting proxy
#                      (HTTPS_PROXY, if set, is passed to the build as well)
set -euo pipefail
ML_DEV_VERSION=0.1.0
IMAGE="kdrill.local/ml-dev:${ML_DEV_VERSION}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "  building $IMAGE (first time only: downloads about 250 MB, 2-5 minutes)..."
  args=(build -t "$IMAGE")
  if [[ -n "${KDRILL_BUILD_CA:-}" ]]; then args+=(--secret "id=ca,src=$KDRILL_BUILD_CA"); fi
  if [[ -n "${HTTPS_PROXY:-}" ]]; then args+=(--network host --build-arg "HTTPS_PROXY=$HTTPS_PROXY"); fi
  log="$(mktemp)"
  DOCKER_BUILDKIT=1 docker "${args[@]}" "$here" >"$log" 2>&1 \
    || { tail -n 30 "$log" >&2; rm -f "$log"; echo "error: building $IMAGE failed" >&2; exit 1; }
  rm -f "$log"
fi
echo "$IMAGE"
