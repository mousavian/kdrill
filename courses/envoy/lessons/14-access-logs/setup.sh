source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend web
service down-pods app=nothing-yet --headless
apply_lesson manifests/envoy-config.yaml
envoy_up
lab_wait web envoy
