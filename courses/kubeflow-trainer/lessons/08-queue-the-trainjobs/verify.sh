source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
CQ=clusterqueue.kueue.x-k8s.io/training-cq
check_eq "ClusterQueue training-cq is unchanged" "$(baseline_get quota)" "$(jp $CQ '{.spec.resourceGroups}')"
why "Use the queue as it is: the quota is sized for one TrainJob at a time."
check_eq "LocalQueue training points to training-cq" training-cq "$(jp localqueue.kueue.x-k8s.io/training '{.spec.clusterQueue}')"
for j in exp-a exp-b; do
  if ! kubectl get $TJ $j >/dev/null 2>&1; then check "TrainJob $j exists" false; continue; fi
  check_eq "$j is submitted to the queue training (label kueue.x-k8s.io/queue-name)" training "$(jp $TJ/$j '{.metadata.labels.kueue\.x-k8s\.io/queue-name}')"
  why "Kueue only manages TrainJobs created with the label; delete the job and create it again with it."
  check_eq "$j still asks for 2 nodes and 400 steps" "2 400" "$(jp $TJ/$j '{.spec.trainer.numNodes} {.spec.trainer.args[1]}')"
  w="$(wl_of TrainJob $j)"
  check "$j has a Kueue Workload (owned by the TrainJob)" test -n "$w"
  [[ -n "$w" ]] && check_eq "The Workload's podSet counts 2 nodes" 2 "$(jp workloads.kueue.x-k8s.io/$w '{.spec.podSets[?(@.name=="node")].count}')"
done
wa="$(wl_of TrainJob exp-a)"; wb="$(wl_of TrainJob exp-b)"
[[ -n "$wa" && -n "$wb" ]] || exit 1
fail_fast
sa="$(tj_state exp-a)"; sb="$(tj_state exp-b)"
end=$((SECONDS + 100))
while (( SECONDS < end )); do
  sa="$(tj_state exp-a)"; sb="$(tj_state exp-b)"
  [[ "$sa" == complete && "$sb" == complete ]] && break
  [[ "$(wl_cond "$wa" Admitted)" == True && "$(wl_cond "$wb" Admitted)" == True && "$sa" != complete && "$sb" != complete ]] && break
  sleep 3
done
if [[ "$sa" != complete || "$sb" != complete ]]; then
  check "Never both admitted at once (exp-a: $sa, exp-b: $sb)" bash -c '! [[ "$1" == True && "$2" == True ]]' _ "$(wl_cond "$wa" Admitted)" "$(wl_cond "$wb" Admitted)"
  why "One TrainJob needs the whole CPU quota: the other must wait in the queue, suspended, with no pods."
  check "Both TrainJobs have finished, one after the other (exp-a: $sa, exp-b: $sb; about 1-2 minutes)" false
  why "Verify again when both are complete."
  exit 1
fi
check "exp-a and exp-b completed" true
for j in exp-a exp-b; do
  check "$j trained as one 2-node group" bash -c 'grep -q "all 2 workers connected" <<<"$1"' _ "$(tj_logs $j node)"
done
fa="$(wl_time "$wa" Finished)"; fb="$(wl_time "$wb" Finished)"
qa="$(wl_time "$wa" Admitted)"; qb="$(wl_time "$wb" Admitted)"
if [[ "$qa" < "$qb" ]]; then first=exp-a; f1="$fa"; q2="$qb"; else first=exp-b; f1="$fb"; q2="$qa"; fi
check "The second TrainJob was admitted only after $first finished ($first finished $f1, the other admitted $q2)" \
  bash -c '[[ -n "$1" && -n "$2" && ! "$2" < "$1" ]]' _ "$f1" "$q2"
why "Both ran at the same time: were both created with the queue label?"
