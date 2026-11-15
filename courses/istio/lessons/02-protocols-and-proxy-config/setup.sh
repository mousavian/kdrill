source "$KDRILL_HOME/courses/istio/lib.sh"
ist_setup_start
mesh_ns store
apply_lesson manifests/store.yaml manifests/services.yaml manifests/virtualservice.yaml
rollouts_all store
