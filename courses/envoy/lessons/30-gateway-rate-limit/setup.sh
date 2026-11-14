source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend api
apply_lesson manifests/api.yaml
lab_wait api
gw_wait edge
