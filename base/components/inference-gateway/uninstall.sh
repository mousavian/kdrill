# Remove the inference CRDs (and every InferencePool / InferenceObjective with
# them) and switch Lua in Envoy Gateway off again. Safe when Envoy Gateway is gone.
set +e
kubectl get crd -o name 2>/dev/null | grep -E '(inference\.networking\.k8s\.io|llm-d\.ai)$' \
  | xargs kubectl delete --ignore-not-found --timeout=60s >/dev/null 2>&1
if kubectl -n envoy-gateway-system get cm envoy-gateway-config >/dev/null 2>&1; then
  cm="$(kubectl -n envoy-gateway-system get cm envoy-gateway-config -o jsonpath='{.data.envoy-gateway\.yaml}')"
  if [[ "$cm" == *"enableLua: true"* ]]; then
    new="$(printf '%s\n' "$cm" | sed '/^  enableLua: true$/d; s/^extensionApis:$/extensionApis: {}/')"
    kubectl -n envoy-gateway-system create cm envoy-gateway-config --from-literal="envoy-gateway.yaml=$new" \
      --dry-run=client -o yaml | kubectl -n envoy-gateway-system apply --server-side --force-conflicts -f - >/dev/null 2>&1
    kubectl -n envoy-gateway-system rollout restart deploy/envoy-gateway >/dev/null 2>&1
    kubectl -n envoy-gateway-system rollout status deploy/envoy-gateway --timeout=120s >/dev/null 2>&1
  fi
fi
info "inference CRDs removed"
