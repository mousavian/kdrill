source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend echo --replicas 3 --headless
apply_lesson manifests/envoy-config.yaml
envoy_up
lab_wait echo envoy
