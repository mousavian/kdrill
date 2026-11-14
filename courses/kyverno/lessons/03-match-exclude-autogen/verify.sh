source "$KDRILL_HOME/courses/kyverno/lib.sh"
MSG="prod Pods must run as non-root"
P=require-run-as-nonroot
# Throw-away namespaces (labelled for this lesson, removed by cleanup).
probe_ns kyv-probe-prod env=prod
probe_ns kyv-probe-other
kyv_settle

check "ClusterPolicy $P exists and is Ready" policy_ready $P
why "kubectl get clusterpolicy $P -o yaml   (status.conditions says why it isn't Ready)"
check_eq "Rule run-as-nonroot still Enforces" "run-as-nonroot=Enforce" "$(rule_actions $P)"

echo "which namespaces"
check_rejects "prod: a Pod without runAsNonRoot is rejected" pod-root.yaml "$MSG" prod
check_rejects "A brand-new namespace labelled env=prod is covered too" pod-root.yaml "$MSG" kyv-probe-prod
why "Select namespaces by label (match.any[].resources.namespaceSelector), not by name."
check_admits "dev (env=dev): the same Pod is admitted" pod-root.yaml dev
check_admits "A namespace without an env label: admitted" pod-root.yaml kyv-probe-other
check_admits "prod: a Pod with runAsNonRoot: true is admitted" pod-nonroot.yaml prod

echo "who"
ok=1
out="$(kubectl --as=system:serviceaccount:prod:backup-agent create --dry-run=server -f "$KYV_PROBE_DIR/pod-root.yaml" -n prod 2>&1)" || ok=0
check_eq "prod: ServiceAccount prod/backup-agent may create the Pod" 1 "$ok"
why "exclude.any[].subjects: [{kind: ServiceAccount, name: backup-agent, namespace: prod}]  $(_short "$out")"
out="$(kubectl --as=system:serviceaccount:prod:deployer create --dry-run=server -f "$KYV_PROBE_DIR/pod-root.yaml" -n prod 2>&1)"
if [[ $? -ne 0 && "$out" == *"$MSG"* ]]; then _kd_ok "prod: ServiceAccount prod/deployer is still rejected"; else _kd_fail "prod: ServiceAccount prod/deployer is still rejected" "$(_short "$out")"; fi

echo "Pod controllers"
check_rejects "prod: a Deployment whose Pod template runs as root is rejected at apply time" deployment-root.yaml "$MSG" prod
why "Remove the pod-policies.kyverno.io/autogen-controllers: none annotation; Kyverno then adds autogen-* rules for Deployments, Jobs, CronJobs, ..."
check_eq "Deployment api: 2 replicas requested, 2 ready" "2 2" "$(jp deploy/api '{.spec.replicas}' -n prod) $(jp deploy/api '{.status.readyReplicas}' -n prod)"
why "kubectl -n prod describe rs -l app=api  (FailedCreate). Fix the Pod template, not the policy."
check_eq "api's Pod template sets runAsNonRoot: true" true "$(jp deploy/api '{.spec.template.spec.securityContext.runAsNonRoot}' -n prod)"
