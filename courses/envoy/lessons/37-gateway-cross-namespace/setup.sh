source "$KDRILL_HOME/courses/envoy/lib.sh"
client_up
backend web
# backend() works in kubectl's current namespace: run it in the other ones.
( kubectl() { command kubectl -n reviews "$@"; }; backend reviews )
( kubectl() { command kubectl -n sandbox "$@"; }; backend experiment )
apply_lesson manifests/gateway.yaml
apply_lesson manifests/routes.yaml
lab_wait web
kubectl -n reviews rollout status deploy/reviews --timeout=120s >/dev/null
kubectl -n sandbox rollout status deploy/experiment --timeout=120s >/dev/null
# The Gateway lives in infra, so its Envoy and its Service `public` do too.
_public_up() {
  [[ "$(jp gateway/public '{.status.conditions[?(@.type=="Programmed")].status}' -n infra)" == True ]] \
    && [[ "$(http_code http://public.infra/ -H 'Host: shop.lab')" != 000 ]]
}
info "waiting for Gateway public and its Envoy (first time: image pull)..."
wait_until 150 _public_up || die "Gateway public is not ready (kubectl -n infra describe gateway public; kubectl -n infra get pods)"
