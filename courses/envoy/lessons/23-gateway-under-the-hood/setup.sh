source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend web
backend cart --replicas 2
apply_lesson manifests/shop.yaml
lab_wait web cart
gw_wait edge
