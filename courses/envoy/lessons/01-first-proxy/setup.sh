source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend echo
apply_lesson manifests/envoy-config.yaml
envoy_up
lab_wait echo      # not envoy: it is meant to crash until you fix it
