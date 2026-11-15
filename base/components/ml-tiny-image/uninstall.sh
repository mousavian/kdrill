# Remove the image from the cluster's node (frees about 800 MB in the node).
# The image stays in the host's Docker so the next start does not rebuild it;
# remove it with: docker rmi kdrill.local/ml-tiny:<version>
v="$(grep -m1 '^ML_TINY_VERSION=' "$KDRILL_HOME/base/images/ml-tiny/build.sh" | cut -d= -f2)"
docker exec "k3d-${KDRILL_CLUSTER:-kdrill}-server-0" crictl rmi "kdrill.local/ml-tiny:$v" >/dev/null 2>&1 || true
info "ml-tiny image removed from the cluster (kept in Docker)"
