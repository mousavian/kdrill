source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend echo --replicas 3 --labels pool=echo --no-service
broken_backend sick --labels pool=echo
service echo pool=echo
apply_lesson manifests/cart.yaml
lab_wait echo sick
gw_wait edge
