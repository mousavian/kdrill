source "$KDRILL_HOME/courses/kyverno/lib.sh"
MSG="every Pod needs a non-empty team label"
kyv_settle

check "ClusterPolicy require-team-label exists and is Ready" policy_ready require-team-label
why "kubectl get clusterpolicy require-team-label; kdrill reset brings it back if you deleted it."
check_eq "Rule check-team is set to Enforce" "check-team=Enforce" "$(rule_actions require-team-label)"
why "In Audit mode a violation is only reported; spec.rules[].validate.failureAction: Enforce blocks the request."

echo "behaviour (server-side dry-run of the files in probes/)"
check_rejects "A Pod without a team label is rejected with \"$MSG\"" pod-no-team.yaml "$MSG"
check_rejects "A Pod with an empty team label is rejected with \"$MSG\"" pod-empty-team.yaml "$MSG"
why "In a pattern, \"*\" matches any value, including the empty string. \"?*\" means at least one character."
check_admits "A Pod with team=payments is admitted" pod-team.yaml

echo "workload"
check_eq "Deployment web: 2 replicas ready" 2 "$(jp deploy/web '{.status.readyReplicas}' -n shop)"
check_eq "Deployment web: still 2 replicas requested" 2 "$(jp deploy/web '{.spec.replicas}' -n shop)"
team="$(jp deploy/web '{.spec.template.metadata.labels.team}' -n shop)"
check "Deployment web's Pod template has a non-empty team label" test -n "$team"
why "Existing Pods are not re-checked at admission; the next rollout would be rejected. Add the label to the Deployment's Pod template."
bad="$(kubectl -n shop get pods -l app=web -o jsonpath='{range .items[*]}{.metadata.labels.team}{"|"}{end}' 2>/dev/null | tr '|' '\n' | grep -c '^$')"
check_eq "Every web Pod carries the team label" 0 "$bad"
