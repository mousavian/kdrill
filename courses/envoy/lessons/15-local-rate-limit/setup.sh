source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend api
apply_lesson manifests/envoy-config.yaml
envoy_up
lab_wait api envoy
