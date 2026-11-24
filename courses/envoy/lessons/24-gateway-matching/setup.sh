source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend web
backend api-v1
backend api-v2
backend orders
apply_lesson manifests/routes.yaml
lab_wait web api-v1 api-v2 orders
gw_wait edge
