source "$KDRILL_HOME/courses/istio/lib.sh"
ist_setup_start
apply_lesson manifests/mall.yaml
rollouts_all mall
