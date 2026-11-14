# Envoy Gateway: Gateway API controller that programs Envoy over xDS. Used by
# the envoy course (Part B). Pinned chart; lean settings in values.yaml.
# Installs the Gateway API CRDs (experimental channel v1.6.1, bundled with the
# chart), Envoy Gateway's CRDs and the GatewayClass `eg`.
EG_VERSION="${EG_VERSION:-v1.9.3}"
here="$KDRILL_HOME/base/components/envoy-gateway"
command -v helm >/dev/null || die "helm is required for the envoy-gateway component (brew install helm)"

helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm --version "$EG_VERSION" \
  --namespace envoy-gateway-system --create-namespace \
  -f "$here/values.yaml" --wait --timeout 8m >/dev/null 2>&1 \
  || helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm --version "$EG_VERSION" \
       --namespace envoy-gateway-system --create-namespace \
       -f "$here/values.yaml" --wait --timeout 8m >/dev/null
kubectl -n envoy-gateway-system rollout status deploy/envoy-gateway --timeout=300s >/dev/null

kubectl apply -f - >/dev/null <<'YAML'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  description: Envoy Gateway (kdrill component envoy-gateway)
YAML
accepted() { [[ "$(kubectl get gatewayclass eg -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}')" == True ]]; }
wait_until 120 accepted || die "GatewayClass eg was not accepted by Envoy Gateway"
info "envoy gateway $EG_VERSION ready (GatewayClass eg)"
