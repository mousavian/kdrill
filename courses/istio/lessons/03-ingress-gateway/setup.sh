source "$KDRILL_HOME/courses/istio/lib.sh"
ist_setup_start
mesh_ns shop
apply_lesson manifests/shop.yaml manifests/outside.yaml
rollouts_all shop
rollouts_all outside
