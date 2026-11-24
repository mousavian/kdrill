# Exit 0 when the component is installed and healthy; kdrill reinstalls it otherwise.
node="k3d-${KDRILL_CLUSTER:-kdrill}-server-0"
docker exec "$node" crictl inspecti kdrill.local/smollm2-135m:q4km >/dev/null 2>&1
docker exec "$node" sh -c 'ls /var/lib/kdrill/models/* >/dev/null 2>&1'
