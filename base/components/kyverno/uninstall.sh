# Remove Kyverno completely: policies, reports, CRDs and - most importantly -
# the webhook configurations Kyverno registers at runtime (helm does not own
# them). A webhook left behind with no controller would intercept requests.
set +e
groups='kyverno.io|policies.kyverno.io|reports.kyverno.io|wgpolicyk8s.io'
crds() { kubectl get crd -o name 2>/dev/null | grep -E "\.(${groups//./\\.})$"; }

# Policies first, while the controllers still run (generated VAPs are owned by them).
for k in $(crds | sed 's|.*/||'); do
  kubectl delete "$k" --all -A --ignore-not-found --wait=false >/dev/null 2>&1
done
helm uninstall kyverno -n kyverno --wait --timeout 3m >/dev/null 2>&1
kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration \
  -l webhook.kyverno.io/managed-by=kyverno --ignore-not-found >/dev/null 2>&1
for w in $(kubectl get validatingwebhookconfiguration,mutatingwebhookconfiguration -o name 2>/dev/null | grep '/kyverno-'); do
  kubectl delete "$w" --ignore-not-found >/dev/null 2>&1
done
kubectl delete validatingadmissionpolicy,validatingadmissionpolicybinding \
  -l app.kubernetes.io/managed-by=kyverno --ignore-not-found >/dev/null 2>&1
# CRDs carry helm.sh/resource-policy: keep, so helm leaves them.
crds | xargs -r kubectl delete --ignore-not-found --timeout=60s >/dev/null 2>&1
kubectl delete clusterrole,clusterrolebinding -l app.kubernetes.io/part-of=kyverno --ignore-not-found >/dev/null 2>&1
kubectl delete ns kyverno --ignore-not-found --timeout=120s >/dev/null 2>&1
info "kyverno removed"
