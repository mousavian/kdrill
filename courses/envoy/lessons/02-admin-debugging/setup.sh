source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend shop
backend catalog
backend api
apply_lesson manifests/envoy-config.yaml
envoy_up
lab_wait shop catalog api envoy
