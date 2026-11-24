source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend web
apply_lesson manifests/edge.yaml
lab_wait web
gw_wait edge
