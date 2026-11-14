source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend echo-v1 --name v1
backend echo-v2 --name v2
apply_lesson manifests/envoy-config.yaml
envoy_up
lab_wait echo-v1 echo-v2 envoy
