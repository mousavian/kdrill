source "$KDRILL_HOME/courses/istio/lib.sh"
ist_setup_start
mesh_ns shop
apply_lesson manifests/workloads.yaml manifests/outside.yaml manifests/services.yaml manifests/mesh.yaml manifests/gateway.yaml
rollouts_all shop
rollouts_all outside
kubectl -n shop wait gateway.gateway.networking.k8s.io/shop-gateway --for=condition=Programmed --timeout=90s >/dev/null 2>&1 || true
rollouts shop shop-gateway-istio
