# Model weights and model-server images for the inference course.
#   - downloads SmolLM2-135M-Instruct (Q4_K_M GGUF, Apache-2.0, 105 MB) once into
#     $KDRILL_STATE_DIR/models, verifies its sha256, and copies it into the k3d
#     node at /var/lib/kdrill/models (lessons mount that directory as a hostPath)
#   - builds the same file into a FROM-scratch OCI image
#     kdrill.local/smollm2-135m:q4km and imports it into the cluster (lessons
#     mount it as an image volume)
#   - pulls the pinned llama.cpp server, llm-d-inference-sim, endpoint picker and
#     python images into the node's containerd so lessons never wait on a registry
# Lessons never download anything. Idempotent.
MODEL_REPO_REV="09816acd5d99df7be770d85ea30822623dab342c"
MODEL_FILE="SmolLM2-135M-Instruct-Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF/resolve/${MODEL_REPO_REV}/${MODEL_FILE}"
MODEL_SHA256="2e8040ceae7815abe0dcb3540b9995eaa1fa0d2ca9e797d0a635ae4433c68c2d"
NODE_MODEL="smollm2-135m-instruct-q4_k_m.gguf"
MODEL_IMAGE="kdrill.local/smollm2-135m:q4km"
IMAGES="
ghcr.io/ggml-org/llama.cpp@sha256:c7d58273d753d33a352e5c41ab300c5ae040a16fa4b202231bb606478065c124
ghcr.io/llm-d/llm-d-inference-sim@sha256:9992453829c0dea8d120b8e0322bb0e4237cbb3c6d9ea3bdce060410c40c91c9
ghcr.io/llm-d/llm-d-router-endpoint-picker@sha256:024188e998f516879f68532016ca24fabca00afbdcc2af9a61b17634e197df2c
docker.io/library/python@sha256:9ef1a599f863231c3d91e941389bfdc4a2d6070557243d54df1a4e57015b960e
docker.io/curlimages/curl:8.22.0
"
node="k3d-${KDRILL_CLUSTER:-kdrill}-server-0"
cache="${KDRILL_STATE_DIR:-$HOME/.kdrill}/models"
command -v docker >/dev/null || die "docker is required for the inference-models component"
command -v curl >/dev/null || die "curl is required for the inference-models component"

sha_of() { shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'; }
mkdir -p "$cache"
if [[ "$(sha_of "$cache/$MODEL_FILE")" != "$MODEL_SHA256" ]]; then
  info "downloading $MODEL_FILE (105 MB, once) ..."
  curl -fsSL --retry 3 -o "$cache/$MODEL_FILE.part" "$MODEL_URL" || die "download of $MODEL_URL failed"
  [[ "$(sha_of "$cache/$MODEL_FILE.part")" == "$MODEL_SHA256" ]] || { rm -f "$cache/$MODEL_FILE.part"; die "checksum of $MODEL_FILE does not match the pinned sha256"; }
  mv "$cache/$MODEL_FILE.part" "$cache/$MODEL_FILE"
fi

# Weights on the node (hostPath /var/lib/kdrill/models).
if ! docker exec "$node" sh -c "[ -f /var/lib/kdrill/models/$NODE_MODEL ] && [ \$(wc -c < /var/lib/kdrill/models/$NODE_MODEL) -eq $(wc -c < "$cache/$MODEL_FILE" | tr -d ' ') ]"; then
  docker exec "$node" mkdir -p /var/lib/kdrill/models
  docker cp "$cache/$MODEL_FILE" "$node:/var/lib/kdrill/models/$NODE_MODEL"
fi

# Weights as an OCI image (image volumes).
if ! docker exec "$node" crictl inspecti "$MODEL_IMAGE" >/dev/null 2>&1; then
  if ! docker image inspect "$MODEL_IMAGE" >/dev/null 2>&1; then
    ctx="$(mktemp -d)"
    cp "$cache/$MODEL_FILE" "$ctx/$NODE_MODEL"
    printf 'FROM scratch\nCOPY %s /%s\n' "$NODE_MODEL" "$NODE_MODEL" > "$ctx/Dockerfile"
    docker build -q -t "$MODEL_IMAGE" "$ctx" >/dev/null || { rm -rf "$ctx"; die "could not build $MODEL_IMAGE"; }
    rm -rf "$ctx"
  fi
  k3d image import -c "${KDRILL_CLUSTER:-kdrill}" "$MODEL_IMAGE" >/dev/null 2>&1 || die "could not import $MODEL_IMAGE into the cluster"
fi

for img in $IMAGES; do
  docker exec "$node" crictl inspecti "$img" >/dev/null 2>&1 && continue
  info "pulling ${img%%@*}"
  docker exec "$node" crictl pull "$img" >/dev/null 2>&1 \
    || docker exec "$node" crictl pull "$img" >/dev/null 2>&1 \
    || die "could not pull $img"
done
info "inference-models ready (model on the node + $MODEL_IMAGE, server/simulator/picker images pulled)"
