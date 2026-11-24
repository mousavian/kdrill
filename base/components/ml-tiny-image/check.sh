# Exit 0 when the image is in the cluster; kdrill re-imports it otherwise.
v="$(sed -n "s/^ML_TINY_VERSION=//p" "$KDRILL_HOME/base/images/ml-tiny/build.sh")"
docker exec "k3d-${KDRILL_CLUSTER:-kdrill}-server-0" crictl inspecti "kdrill.local/ml-tiny:$v" >/dev/null 2>&1
