source "$KDRILL_HOME/courses/istio/lib.sh"
ist_setup_start
mesh_ns bank shop
apply_lesson manifests/bank.yaml manifests/clients.yaml
rollouts_all bank
rollouts_all shop
rollouts_all legacy
