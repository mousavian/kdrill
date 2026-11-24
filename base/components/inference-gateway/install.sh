# What the inference course needs on top of the envoy-gateway component:
#   1. the Gateway API Inference Extension InferencePool CRD (inference.networking.k8s.io, v1.6.2)
#   2. the llm-d router CRDs InferenceObjective and InferenceModelRewrite (llm-d.ai, v1.0.0).
#      The endpoint picker that reads these moved from the inference-extension
#      repository to llm-d/llm-d-router in 2026.
#   3. Lua enabled in Envoy Gateway (extensionApis.enableLua). It is off by
#      default; lesson 13 uses a Lua EnvoyExtensionPolicy to read the model name
#      from the request body.
# Envoy Gateway v1.9.3 cannot use an InferencePool as an HTTPRoute backendRef
# (that needs Envoy AI Gateway), so the lessons wire the endpoint picker in with
# an EnvoyExtensionPolicy (ext_proc) and a BackendTrafficPolicy endpointOverride.
GAIE_VERSION="${GAIE_VERSION:-v1.6.2}"
LLMD_ROUTER_VERSION="${LLMD_ROUTER_VERSION:-v1.0.0}"
kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 \
  || die "the envoy-gateway component must be installed first (Gateway API CRDs are missing)"

kubectl apply --server-side --force-conflicts -f \
  "https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/${GAIE_VERSION}/v1-manifests.yaml" >/dev/null
for f in llm-d.ai_inferenceobjectives llm-d.ai_inferencemodelrewrites; do
  kubectl apply --server-side --force-conflicts -f \
    "https://raw.githubusercontent.com/llm-d/llm-d-router/${LLMD_ROUTER_VERSION}/config/crd/bases/${f}.yaml" >/dev/null
done
kubectl wait --for=condition=Established --timeout=60s \
  crd/inferencepools.inference.networking.k8s.io crd/inferenceobjectives.llm-d.ai crd/inferencemodelrewrites.llm-d.ai >/dev/null

cm="$(kubectl -n envoy-gateway-system get cm envoy-gateway-config -o jsonpath='{.data.envoy-gateway\.yaml}')"
if [[ "$cm" != *"enableLua: true"* ]]; then
  new="$(printf '%s\n' "$cm" | sed 's/^extensionApis: {}$/extensionApis:\
  enableLua: true/')"
  [[ "$new" == *"enableLua: true"* ]] || die "could not enable Lua: unexpected Envoy Gateway configuration"
  kubectl -n envoy-gateway-system create cm envoy-gateway-config --from-literal="envoy-gateway.yaml=$new" \
    --dry-run=client -o yaml | kubectl -n envoy-gateway-system apply --server-side --force-conflicts -f - >/dev/null
  # a restart is needed for the controller to read it
  kubectl -n envoy-gateway-system rollout restart deploy/envoy-gateway >/dev/null
  kubectl -n envoy-gateway-system rollout status deploy/envoy-gateway --timeout=180s >/dev/null
fi
info "inference CRDs (InferencePool $GAIE_VERSION, llm-d router $LLMD_ROUTER_VERSION) installed, Lua enabled in Envoy Gateway"
