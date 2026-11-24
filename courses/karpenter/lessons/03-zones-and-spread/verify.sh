source "$KDRILL_HOME/courses/karpenter/lib.sh"
NS=store
TSC='{.spec.template.spec.topologySpreadConstraints[?(@.topologyKey=="topology.kubernetes.io/zone")]'

echo "checkout"
check_eq "checkout has a zone topology spread constraint: maxSkew 1, DoNotSchedule, minDomains 3" "1 DoNotSchedule 3" \
  "$(jp deploy/checkout "$TSC.maxSkew} $TSC.whenUnsatisfiable} $TSC.minDomains}" -n $NS)"
why "spec.template.spec.topologySpreadConstraints with topologyKey topology.kubernetes.io/zone. ScheduleAnyway is only a preference, and without minDomains the scheduler only knows the zones that already have nodes."
check_eq "checkout: 6 pods Running" 6 "$(live_running $NS app=checkout)"
check_eq "checkout: 2 pods in each zone" "us-west-2a:2 us-west-2b:2 us-west-2c:2" "$(pod_spread $NS app=checkout topology.kubernetes.io/zone)"
why "Uneven although the constraint is there? Old and new pods are counted together during a rollout unless you add matchLabelKeys: [pod-template-hash]. To redo it: kubectl -n $NS rollout restart deploy/checkout"

echo "reports"
check_eq "reports: 2 pods Running" 2 "$(live_running $NS app=reports)"
why "kubectl -n $NS describe pod -l app=reports: which zones does this cloud have? (kubectl get nodes -L topology.kubernetes.io/zone)"
check_eq "reports runs in us-west-2a only" us-west-2a "$(pod_node_labels $NS app=reports topology.kubernetes.io/zone)"

echo "guards"
check_pool_unchanged general general
check_workload_unchanged deploy/checkout $NS checkout
check_workload_unchanged deploy/reports $NS reports
check_only_karpenter_nodes
check_karpenter_up
