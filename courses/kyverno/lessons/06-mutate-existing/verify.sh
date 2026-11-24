source "$KDRILL_HOME/courses/kyverno/lib.sh"
P=propagate-cost-center
L='{.metadata.labels.cost-center}'
lbl() { local v; v="$(jp "$1" "$L" -n "$2")"; echo "${v:-none}"; }
labels() {  # cost-center labels of notebook finetune chat vector-db scratch ("none" if unset)
  echo "$(lbl deploy/notebook research) $(lbl deploy/finetune research) $(lbl deploy/chat inference) $(lbl statefulset/vector-db inference) $(lbl deploy/scratch sandbox)"
}
_labels_are() { [[ "$(labels)" == "$1" ]]; }
kyv_settle

check "ClusterPolicy $P exists and is Ready" policy_ready $P
check_eq "Workloads still there (4 Deployments, 1 StatefulSet)" "notebook finetune chat scratch vector-db" \
  "$(jp deploy/notebook '{.metadata.name}' -n research) $(jp deploy/finetune '{.metadata.name}' -n research) $(jp deploy/chat '{.metadata.name}' -n inference) $(jp deploy/scratch '{.metadata.name}' -n sandbox) $(jp statefulset/vector-db '{.metadata.name}' -n inference)"
why "kdrill reset restores them."

echo "existing workloads (labels of notebook, finetune | chat, vector-db | scratch)"
want="cc-1001 cc-1001 cc-2002 cc-2002 none"
wait_b 30 _labels_are "$want"
got="$(labels)"
check_eq "research Deployments carry cost-center=cc-1001" "cc-1001 cc-1001" "$(echo $got | cut -d' ' -f1-2)"
why "A mutate-existing rule runs when its trigger (the Namespace) changes. To run it for what exists now: spec.mutateExistingOnPolicyUpdate: true."
check_eq "inference Deployment chat carries cost-center=cc-2002" "cc-2002" "$(echo $got | cut -d' ' -f3)"
check_eq "inference StatefulSet vector-db carries cost-center=cc-2002" "cc-2002" "$(echo $got | cut -d' ' -f4)"
why "mutate.targets is a list: add an entry for kind StatefulSet."
check_eq "sandbox (no cost-center label): scratch has no cost-center label" "none" "$(echo $got | cut -d' ' -f5)"

echo "when the namespace label changes (verify sets research to cc-1001-probe and inference to cc-2002-probe, then back)"
kubectl label ns research cost-center=cc-1001-probe --overwrite >/dev/null 2>&1
kubectl label ns inference cost-center=cc-2002-probe --overwrite >/dev/null 2>&1
wait_b 30 _labels_are "cc-1001-probe cc-1001-probe cc-2002-probe cc-2002-probe none"
check_eq "All four workloads follow the new values" "cc-1001-probe cc-1001-probe cc-2002-probe cc-2002-probe" "$(labels | cut -d' ' -f1-4)"
kubectl label ns research cost-center=cc-1001 --overwrite >/dev/null 2>&1
kubectl label ns inference cost-center=cc-2002 --overwrite >/dev/null 2>&1
wait_b 20 _labels_are "$want" || true

echo "guards"
check_eq "Pod templates untouched (no rollouts: every workload at generation 1)" "1 1 1 1 1" \
  "$(jp deploy/notebook '{.metadata.generation}' -n research) $(jp deploy/finetune '{.metadata.generation}' -n research) $(jp deploy/chat '{.metadata.generation}' -n inference) $(jp statefulset/vector-db '{.metadata.generation}' -n inference) $(jp deploy/scratch '{.metadata.generation}' -n sandbox)"
why "Patch metadata.labels of the Deployment, not spec.template (that would restart every Pod)."
own=""
for w in research/deploy/notebook research/deploy/finetune inference/deploy/chat inference/statefulset/vector-db; do
  f="$(kubectl -n "${w%%/*}" get "${w#*/}" -o jsonpath='{.metadata.managedFields[?(@.manager=="background-controller")].fieldsV1}' 2>/dev/null)"
  [[ "$f" == *'"f:cost-center"'* ]] || own+="${w##*/} "
done
check_eq "The cost-center labels were set by Kyverno's background controller (not by hand)" "" "$own"
why "kubectl get deploy -n research notebook -o yaml --show-managed-fields. kdrill reset gives you clean workloads."
