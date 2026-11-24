source "$KDRILL_HOME/courses/karpenter/lib.sh"
GN=karpenter.k8s.aws/instance-gpu-name

echo "prod"
check_eq "checkout: 3 pods Running" 3 "$(live_running prod app=checkout)"
why "kubectl -n prod describe pod -l app=checkout | tail -3 (the karpenter event lists the requirements it tried)"
check_eq "legacy: 1 pod Running" 1 "$(live_running prod app=legacy)"
check_eq "legacy's pods no longer carry karpenter.sh/do-not-disrupt" "" \
  "$(kubectl -n prod get pods -l app=legacy -o jsonpath='{.items[*].metadata.annotations.karpenter\.sh/do-not-disrupt}')"
check_eq "The relabel has rolled out: every general node carries cost-center=shop-v2" shop-v2 "$(karp_node_labels cost-center karpenter.sh/nodepool=general)"
why "kubectl get nodeclaims -o yaml | grep -B2 -A4 Drifted; kubectl describe node <old node> | tail (DisruptionBlocked). Replacement takes ~20-60 s once unblocked."

echo "ml"
check_eq "embed: Running on an L4 in the gpu pool" "1 l4 gpu" \
  "$(live_running ml app=embed) $(pod_node_labels ml app=embed $GN) $(pod_node_labels ml app=embed karpenter.sh/nodepool)"
why "kubectl -n ml describe pod -l app=embed | tail -3"
check_eq "rerank: Running on a 24 GB GPU (l4 or a10g)" yes \
  "$( [[ "$(live_running ml app=rerank)" == 1 ]] && [[ " l4 a10g " == *" $(pod_node_labels ml app=rerank $GN) "* ]] && echo yes)"
check_eq "No idle GPUs in the fleet" 0 "$(idle_gpus)"
why "kubectl get nodes -L node.kubernetes.io/instance-type,$GN,karpenter.k8s.aws/instance-gpu-count; an emptied GPU node goes ~15-30 s later."

echo "batch"
check_eq "crunch: 6 pods Running" 6 "$(live_running batch app=crunch)"
why "kubectl -n batch describe pod -l app=crunch | tail -3; kubectl get nodepool spot -o jsonpath='{.status.resources}'"
check_eq "crunch still tolerates the spot pool's taint (spot stays its first choice)" yes \
  "$(jp deploy/crunch '{.spec.template.spec.tolerations[*].key}' -n batch | grep -qw spot && echo yes)"

echo "guards"
want="$(baseline_get pools)"; got="$(for p in general spot gpu; do echo "$p=$(pool_spec $p)"; done)"
check "NodePools general, spot and gpu are unchanged" test -n "$want" -a "$want" == "$got"
why "The pools are shared infrastructure: fix the workloads. (kdrill reset restores them.)"
for w in prod/checkout prod/legacy ml/embed ml/rerank batch/crunch; do
  check_workload_unchanged "deploy/${w#*/}" "${w%/*}" "${w#*/}"
done
check_only_karpenter_nodes
check_karpenter_up
