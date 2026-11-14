source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend web
backend admin
apply_lesson manifests/site.yaml
lab_wait web admin
gw_wait edge
