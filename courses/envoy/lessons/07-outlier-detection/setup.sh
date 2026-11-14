source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend echo --replicas 2 --labels pool=echo --no-service
broken_backend sick --labels pool=echo
service echo pool=echo --headless
apply_lesson manifests/envoy-config.yaml
envoy_up
lab_wait echo sick envoy
