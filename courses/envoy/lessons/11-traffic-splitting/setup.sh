source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend web-v1 --name v1
backend web-v2 --name v2
apply_lesson manifests/envoy-config.yaml
envoy_up
lab_wait web-v1 web-v2 envoy
