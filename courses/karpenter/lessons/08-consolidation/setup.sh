source "$KDRILL_HOME/courses/karpenter/lib.sh"
karp_require
karp_nodeclass default
karp_apply manifests/nodepool.yaml
# The peak: 12 web + 3 worker pods (15 CPUs) arrive together.
apply_lesson manifests/web.yaml manifests/worker.yaml
karp_wait_running shop app=web 12 60
karp_wait_running shop app=worker 3 30
# ...and the scale-down after it.
kubectl -n shop scale deploy web --replicas=2 >/dev/null
kubectl -n shop scale deploy worker --replicas=1 >/dev/null
karp_wait_running shop app=web 2 30
baseline_save web="res_of deploy/web shop" worker="res_of deploy/worker shop"
