source "$KDRILL_HOME/courses/istio/lib.sh"
ist_setup_start
mesh_ns bank
apply_lesson manifests/bank.yaml manifests/virtualservice.yaml
rollouts_all bank
