# Kyverno policy engine (admission + background + reports controllers). Used by
# the kyverno course. Pinned chart; lean settings live in values.yaml next to
# this script.
KYVERNO_CHART_VERSION="${KYVERNO_CHART_VERSION:-3.9.2}"   # = Kyverno v1.19.2
here="$KDRILL_HOME/base/components/kyverno"
command -v helm >/dev/null || die "helm is required for the kyverno component (brew install helm)"

# The real node must be schedulable for Kyverno even while a sim lesson has
# tainted it: values.yaml adds the toleration and pins the pods to the real
# (control-plane) node, never onto KWOK fake nodes.
helm upgrade --install kyverno kyverno \
  --repo https://kyverno.github.io/kyverno/ --version "$KYVERNO_CHART_VERSION" \
  --namespace kyverno --create-namespace \
  -f "$here/values.yaml" --wait --timeout 8m >/dev/null

for d in kyverno-admission-controller kyverno-background-controller kyverno-reports-controller; do
  kubectl -n kyverno rollout status "deploy/$d" --timeout=300s >/dev/null
done

# The webhook serves with a certificate Kyverno generates itself and registers
# its webhook configurations a few seconds after it starts. Wait until a
# throw-away Enforce policy really rejects a dry-run request.
kubectl apply -f - >/dev/null 2>&1 <<'YAML'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: kdrill-webhook-probe
spec:
  validationFailureAction: Enforce
  background: false
  rules:
  - name: probe
    match:
      any:
      - resources:
          kinds: [ConfigMap]
          names: [kdrill-webhook-probe]
    validate:
      message: kdrill-webhook-probe
      deny: {}
YAML
probe() {   # (no pipe: under pipefail kubectl's non-zero exit would fail it)
  local out
  out="$(kubectl -n default create configmap kdrill-webhook-probe --dry-run=server 2>&1)"
  [[ "$out" == *"probe: kdrill-webhook-probe"* ]]
}
ok=0; wait_until 180 probe && ok=1
kubectl delete clusterpolicy kdrill-webhook-probe --ignore-not-found >/dev/null 2>&1 || true
(( ok == 1 )) || die "kyverno webhook did not become ready"
info "kyverno $(kubectl -n kyverno get deploy kyverno-admission-controller -o jsonpath='{.spec.template.spec.containers[0].image}' | sed 's/.*://') ready (chart $KYVERNO_CHART_VERSION)"
