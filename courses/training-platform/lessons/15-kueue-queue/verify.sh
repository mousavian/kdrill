source "$KDRILL_HOME/courses/training-platform/lib.sh"
check_eq "ClusterQueue training-cq is unchanged" "$(baseline_get quota)" "$(jp clusterqueue.kueue.x-k8s.io/training-cq '{.spec.resourceGroups}')"
why "Use the queue as it is; the quota is set for one job at a time."
check_eq "LocalQueue training points to training-cq" training-cq "$(jp localqueue.kueue.x-k8s.io/training '{.spec.clusterQueue}')"
for j in exp-a exp-b; do
  if ! kubectl get job $j >/dev/null 2>&1; then check "Job $j exists" false; continue; fi
  check_eq "$j is submitted to the queue training (label kueue.x-k8s.io/queue-name)" training "$(jp job/$j '{.metadata.labels.kueue\.x-k8s\.io/queue-name}')"
  check_eq "$j still requests 1 CPU and trains 500 steps" "1 500" "$(jp job/$j '{.spec.template.spec.containers[0].resources.requests.cpu}') $(env_of job/$j STEPS)"
  check "$j has a Kueue Workload" test -n "$(wl_of Job $j)"
  why "No Workload: Kueue only manages Jobs created with the label (it refuses to add it later). Delete the Job and create it with the label."
done
wa="$(wl_of Job exp-a)"; wb="$(wl_of Job exp-b)"
[[ -n "$wa" && -n "$wb" ]] || exit 1
sa="$(job_state exp-a)"; sb="$(job_state exp-b)"
if [[ "$sa" != complete || "$sb" != complete ]]; then
  ra="$(wl_cond "$wa" QuotaReserved)"; rb="$(wl_cond "$wb" QuotaReserved)"
  check "Never both admitted at once (exp-a: $sa, exp-b: $sb)" bash -c '! [[ "$1" == True && "$2" == True && "$3" == running && "$4" == running ]]' _ "$ra" "$rb" "$sa" "$sb"
  check "Both experiments have finished, one after the other (exp-a: $sa, exp-b: $sb; about 2 minutes in all)" false
  why "One runs, the other waits suspended in the queue; verify again when both are complete."
  exit 1
fi
check "exp-a and exp-b completed" true
fa="$(wl_time "$wa" Finished)"; fb="$(wl_time "$wb" Finished)"
qa="$(wl_time "$wa" QuotaReserved)"; qb="$(wl_time "$wb" QuotaReserved)"
if [[ "$qa" < "$qb" ]]; then first=exp-a; f1="$fa"; q2="$qb"; else first=exp-b; f1="$fb"; q2="$qa"; fi
check "The second experiment was admitted only after $first finished ($first finished $f1, the other admitted $q2)" \
  bash -c '[[ -n "$1" && -n "$2" && ! "$2" < "$1" ]]' _ "$f1" "$q2"
why "Both ran at the same time: were both Jobs created with the queue label?"
