source "$KDRILL_HOME/courses/istio/lib.sh"
ist_setup_start
apply_lesson manifests/shop.yaml
rollouts_all shop
