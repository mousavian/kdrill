# Remove the model from the node and the images this component added. The
# downloaded GGUF stays in $KDRILL_STATE_DIR/models so the next start does not
# download it again (delete that folder to reclaim 105 MB).
node="k3d-${KDRILL_CLUSTER:-kdrill}-server-0"
set +e
docker exec "$node" rm -rf /var/lib/kdrill/models >/dev/null 2>&1
docker exec "$node" crictl rmi kdrill.local/smollm2-135m:q4km >/dev/null 2>&1
docker rmi kdrill.local/smollm2-135m:q4km >/dev/null 2>&1
info "inference-models removed (the downloaded GGUF is kept in ${KDRILL_STATE_DIR:-$HOME/.kdrill}/models)"
