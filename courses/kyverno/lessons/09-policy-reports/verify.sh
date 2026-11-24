source "$KDRILL_HOME/courses/kyverno/lib.sh"
P=best-practices
# report rows: "<ns> <kind> <name> <fail-count for best-practices>"
rows() {
  local ns
  for ns in team-a team-b; do
    kubectl -n $ns get policyreports.wgpolicyk8s.io -o jsonpath='{range .items[*]}{.scope.kind} {.scope.name} {range .results[?(@.policy=="best-practices")]}{.result},{end}{"\n"}{end}' 2>/dev/null \
      | awk -v ns=$ns 'NF>=2 {n=gsub(/fail,/,"",$3); print ns, $1, $2, n+0}'
  done
}
dep_reports() { rows | awk '$2=="Deployment"' | wc -l | tr -d ' '; }
failing() { rows | awk '($2=="Deployment" || $2=="Pod") && $4>0 {print $1"/"$3}' | sort -u | paste -sd' ' -; }
_six() { [[ "$(dep_reports)" -ge 6 ]]; }
_clean() { [[ -z "$(failing)" ]]; }
kyv_settle

check "ClusterPolicy $P exists and is Ready" policy_ready $P
check_eq "Background scanning is on" true "$(jp clusterpolicy/$P '{.spec.background}')"
why "With background: false Kyverno only checks new requests, so existing workloads never show up in reports."

echo "PolicyReports (team-a, team-b)"
wait_b 40 _six
check_ge "Every Deployment in team-a/team-b has a report for $P" 6 "$(dep_reports)"
why "kubectl get policyreports -A   (reports appear a few seconds after background scanning is enabled)"
wait_b 40 _clean
f="$(failing)"; [[ "$(dep_reports)" -ge 6 ]] || f="${f:-(no reports yet)}"
check_eq "No Deployment or Pod in team-a/team-b fails $P" "" "$f"
why "Fix the workloads the reports name (kubectl get polr -n team-a -o wide; kubectl -n team-a get polr <name> -o yaml)."

echo "enforce"
check_eq "Both rules Enforce" "pin-image-tag=Enforce require-memory-limit=Enforce" "$(rule_actions $P | tr ' ' '\n' | sort | paste -sd' ' -)"
check_rejects "team-a: a Pod with a :latest image is rejected" pod-latest.yaml "use a pinned image tag" team-a
check_rejects "team-b: a Pod without a memory limit is rejected" pod-no-limit.yaml "every container needs a memory limit" team-b
check_admits "team-b: a compliant Pod is admitted" pod-good.yaml team-b

echo "workloads"
ready=""
for w in team-a/api team-a/worker team-a/cache team-b/frontend team-b/embedder team-b/metrics; do
  ready+="$(jp deploy/${w#*/} '{.status.readyReplicas}' -n ${w%/*}) "
done
check_eq "All six Deployments still exist with 1 ready replica" "1 1 1 1 1 1" "${ready% }"
why "Fix them, don't delete them. kdrill reset restores them."
