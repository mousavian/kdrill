# Runs on `kdrill course start training-platform`, after the components.
source "$KDRILL_HOME/courses/training-platform/lib.sh"
# MinIO (lesson 09) is pulled now so that lesson never waits on a registry.
node="k3d-${KDRILL_CLUSTER:-kdrill}-server-0"
if command -v docker >/dev/null 2>&1 && ! docker exec "$node" crictl inspecti "$MINIO_IMAGE" >/dev/null 2>&1; then
  info "pulling MinIO (about 65 MB, once)"
  docker exec "$node" crictl pull "$MINIO_IMAGE" >/dev/null 2>&1 || info "(could not pre-pull MinIO; lesson 09 will pull it)"
fi
guard_fake_nodes
