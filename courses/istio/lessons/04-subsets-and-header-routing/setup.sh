source "$KDRILL_HOME/courses/istio/lib.sh"
ist_setup_start
mesh_ns shop
apply_lesson manifests/shop.yaml manifests/destinationrule.yaml
rollouts_all shop
