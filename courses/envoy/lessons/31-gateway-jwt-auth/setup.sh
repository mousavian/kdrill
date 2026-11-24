source "$KDRILL_HOME/courses/envoy/lib.sh"
kubectl create configmap jwks --from-file=jwks="$JWT_DIR/jwks.json" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
jwt_tokens_configmap
client_up
backend shop
apply_lesson manifests/api.yaml
lab_wait shop
gw_wait edge
