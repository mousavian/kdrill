source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend api
backend api-shadow --name shadow
apply_lesson manifests/routes.yaml
lab_wait api api-shadow
gw_wait edge
