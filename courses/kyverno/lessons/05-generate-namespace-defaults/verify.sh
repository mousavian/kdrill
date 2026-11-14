source "$KDRILL_HOME/courses/kyverno/lib.sh"
P=tenant-defaults
has3() {  # NS -> "netpol quota cm" presence as yes/no words
  local ns="$1"
  printf '%s %s %s' \
    "$( [[ "$(jp networkpolicy/default-deny '{.spec.policyTypes[*]}' -n "$ns")" == Ingress && -z "$(jp networkpolicy/default-deny '{.spec.podSelector.matchLabels}' -n "$ns")" ]] && echo yes || echo no)" \
    "$( [[ "$(jp resourcequota/gpu-quota '{.spec.hard.requests\.nvidia\.com/gpu}' -n "$ns")" == 4 ]] && echo yes || echo no)" \
    "$( [[ -n "$(jp configmap/ca-bundle '{.data.ca\.crt}' -n "$ns")" && "$(jp configmap/ca-bundle '{.data}' -n "$ns")" == "$(jp configmap/ca-bundle '{.data}' -n platform)" ]] && echo yes || echo no)"
}
_all3() { [[ "$(has3 "$1")" == "yes yes yes" ]]; }
_netpol_back() { [[ -n "$(jp networkpolicy/default-deny '{.metadata.uid}' -n "$1")" && "$(jp networkpolicy/default-deny '{.metadata.uid}' -n "$1")" != "$2" ]]; }
_quota_back() { [[ "$(jp resourcequota/gpu-quota '{.spec.hard.requests\.nvidia\.com/gpu}' -n "$1")" == 4 ]]; }
_stamp_copied() { [[ "$(jp configmap/ca-bundle '{.data.kdrill-probe}' -n "$1")" == "$2" ]]; }

kyv_settle
check "ClusterPolicy $P exists and is Ready" policy_ready $P
check_eq "ConfigMap platform/ca-bundle (the clone source) still exists" yes "$( [[ -n "$(jp configmap/ca-bundle '{.data.ca\.crt}' -n platform)" ]] && echo yes || echo no)"

echo "existing tenant namespaces (NetworkPolicy default-deny, ResourceQuota gpu-quota, ConfigMap ca-bundle)"
for ns in team-a team-b; do
  wait_b 20 _all3 $ns
  check_eq "$ns has all three" "yes yes yes" "$(has3 $ns)"
done
why "Generate rules fire when the trigger (a Namespace) is created or updated. For namespaces that already exist: generate.generateExisting: true."

echo "a new tenant namespace (verify creates kyv-probe-tenant, tenant=probe)"
probe_ns kyv-probe-tenant tenant=probe
probe_ns kyv-probe-plain
wait_b 30 _all3 kyv-probe-tenant
check_eq "kyv-probe-tenant gets all three" "yes yes yes" "$(has3 kyv-probe-tenant)"
check_eq "a namespace without the tenant label gets none" "no no no" "$(has3 kyv-probe-plain)"

echo "synchronize"
uid="$(jp networkpolicy/default-deny '{.metadata.uid}' -n kyv-probe-tenant)"
kubectl -n kyv-probe-tenant delete networkpolicy default-deny --ignore-not-found >/dev/null 2>&1
wait_b 30 _netpol_back kyv-probe-tenant "$uid"
check "Deleting the generated NetworkPolicy: Kyverno re-creates it" _netpol_back kyv-probe-tenant "$uid"
why "generate.synchronize: true makes Kyverno own the downstream object."
kubectl -n kyv-probe-tenant patch resourcequota gpu-quota --type=merge -p '{"spec":{"hard":{"requests.nvidia.com/gpu":"64"}}}' >/dev/null 2>&1
wait_b 30 _quota_back kyv-probe-tenant
check "Raising the generated quota by hand: Kyverno reverts it to 4" _quota_back kyv-probe-tenant
stamp="s$(date +%s)"
kubectl -n platform patch configmap ca-bundle --type=merge -p "{\"data\":{\"kdrill-probe\":\"$stamp\"}}" >/dev/null 2>&1
wait_b 40 _stamp_copied team-a "$stamp"
check "A change to platform/ca-bundle reaches the copy in team-a" _stamp_copied team-a "$stamp"
why "clone + synchronize: true keeps the copies in sync with the source."
kubectl -n platform patch configmap ca-bundle --type=json -p '[{"op":"remove","path":"/data/kdrill-probe"}]' >/dev/null 2>&1
