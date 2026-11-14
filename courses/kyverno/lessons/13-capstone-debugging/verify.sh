source "$KDRILL_HOME/courses/kyverno/lib.sh"
T='{.spec.tolerations[*].key}'
kyv_settle

echo "policies"
for p in require-owner-label restrict-registries require-run-as-nonroot gpu-tier; do
  check "ClusterPolicy $p exists and is Ready" policy_ready $p
done
check_eq "No policy got an exclude block (fix the bugs, don't carve out)" "" \
  "$(kubectl get clusterpolicies -o jsonpath='{range .items[*]}{.spec.rules[*].exclude}{end}' 2>/dev/null)"

echo "1 require-owner-label"
check_rejects "payments: Pod without owner label is rejected" pod-no-owner.yaml "Pods in prod namespaces need a non-empty owner label" payments
echo "2 restrict-registries"
check_rejects "analytics: Pod with a docker.io image is rejected" pod-dockerhub.yaml "images must come from registry.acme.io" analytics
echo "3 require-run-as-nonroot"
check_rejects "payments: Pod without securityContext is rejected" pod-no-securitycontext.yaml "Pods in prod namespaces must set runAsNonRoot" payments
check_rejects "payments: Job with such a Pod template is rejected at apply time" job-root.yaml "Pods in prod namespaces must set runAsNonRoot" payments
check_rejects "payments: CronJob with such a Pod template is rejected at apply time" cronjob-root.yaml "Pods in prod namespaces must set runAsNonRoot" payments
echo "4 gpu-tier"
check_eq "GPU Pod: labelled scheduling.acme.io/tier=gpu and tolerates nvidia.com/gpu (once)" "gpu 1" \
  "$(dr_get pod-gpu.yaml '{.metadata.labels.scheduling\.acme\.io/tier}' payments) $(dr_get pod-gpu.yaml "$T" payments | tr ' ' '\n' | grep -cx nvidia.com/gpu)"
echo "not too strict"
check_admits "payments: a compliant Pod is admitted" pod-good.yaml payments
check_admits "playground (env=dev): anything goes" pod-anything.yaml playground
check_eq "No toleration on non-GPU Pods" 0 "$(dr_get pod-good.yaml "$T" payments | tr ' ' '\n' | grep -cx nvidia.com/gpu)"

echo "workloads"
check_eq "checkout 2 ready, reports 1 ready, scratch 1 ready" "2 1 1" \
  "$(jp deploy/checkout '{.status.readyReplicas}' -n payments) $(jp deploy/reports '{.status.readyReplicas}' -n analytics) $(jp deploy/scratch '{.status.readyReplicas}' -n playground)"
check_eq "fraud-model: 1 ready, on the GPU node" "1 yes" \
  "$(jp deploy/fraud-model '{.status.readyReplicas}' -n payments) $(kubectl -n payments get pods -l app=fraud-model --field-selector=status.phase=Running -o jsonpath='{.items[*].spec.nodeName}' 2>/dev/null | grep -qx gpu-1 && echo yes)"
why "Mutations only apply to new Pods: kubectl -n payments rollout restart deploy fraud-model"
check_eq "Workloads unchanged (fraud-model has no hand-made toleration; replicas 2/1/1/1)" "|2 1 1 1" \
  "$(jp deploy/fraud-model '{.spec.template.spec.tolerations}' -n payments)|$(jp deploy/checkout '{.spec.replicas}' -n payments) $(jp deploy/fraud-model '{.spec.replicas}' -n payments) $(jp deploy/reports '{.spec.replicas}' -n analytics) $(jp deploy/scratch '{.spec.replicas}' -n playground)"
why "Fix the policies, not the workloads. kdrill reset restores them."
