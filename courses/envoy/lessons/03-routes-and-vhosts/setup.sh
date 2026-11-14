source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend web
backend api-v1
backend api-v2
apply_lesson manifests/envoy-config.yaml
envoy_up
lab_wait web api-v1 api-v2 envoy
