source "$KDRILL_HOME/courses/envoy/lib.sh"
kubectl create secret generic envoy-certs --from-file=jwks.json="$JWT_DIR/jwks.json" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
jwt_tokens_configmap
client_up
backend shop
apply_lesson manifests/envoy-config.yaml
envoy_up
lab_wait shop envoy
