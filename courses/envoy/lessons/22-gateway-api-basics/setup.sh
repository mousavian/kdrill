source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend web
backend api
apply_lesson manifests/edge.yaml
lab_wait web api
