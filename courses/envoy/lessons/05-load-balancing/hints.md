See what happens now, for one user:

    kubectl exec client -- hits -p -n 9 http://envoy:10000/cart -H 'x-user: alice'

Round robin sends alice's requests to every pod in turn. Stickiness needs
two pieces in Envoy: a **hash policy** on the route (what to hash) and a
**consistent-hash load balancer** on the cluster (how hashes map to hosts).
---
- Route: `route: {cluster: echo, hash_policy: [{header: {header_name: x-user}}]}`
- Cluster: `lb_policy: RING_HASH` (or `MAGLEV`).

Without the hash policy, a RING_HASH cluster picks a random host for
each request.
---
    kubectl apply -f solution/envoy-config.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
