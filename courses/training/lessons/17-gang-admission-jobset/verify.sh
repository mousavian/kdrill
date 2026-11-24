source "$KDRILL_HOME/courses/training/lib.sh"
check_eq "ClusterQueue training-cq is unchanged" "$(baseline_get quota)" "$(jp clusterqueue.kueue.x-k8s.io/training-cq '{.spec.resourceGroups}')"
check_eq "LocalQueue training points to training-cq" training-cq "$(jp localqueue.kueue.x-k8s.io/training '{.spec.clusterQueue}')"
ok=1
for j in ddp-a ddp-b; do
  js=jobset.jobset.x-k8s.io/$j
  if ! kubectl get $js >/dev/null 2>&1; then check "JobSet $j exists" false; ok=0; continue; fi
  check_eq "$j: the JobSet itself is submitted to queue training" training "$(jp $js '{.metadata.labels.kueue\.x-k8s\.io/queue-name}')"
  check_eq "$j: still 2 workers of 750m CPU (WORLD_SIZE 2)" "2 2 750m 2" \
    "$(jp $js '{.spec.replicatedJobs[0].template.spec.completions} {.spec.replicatedJobs[0].template.spec.parallelism} {.spec.replicatedJobs[0].template.spec.template.spec.containers[0].resources.requests.cpu} {.spec.replicatedJobs[0].template.spec.template.spec.containers[0].env[?(@.name=="WORLD_SIZE")].value}')"
  w="$(wl_of JobSet $j)"
  if [[ -z "$w" ]]; then check "$j has one Kueue Workload for the whole set" false; ok=0; continue; fi
  check_eq "$j: its Workload covers both workers (podSets count)" 2 \
    "$(jp workloads.kueue.x-k8s.io/$w '{.spec.podSets[*].count}' | tr ' ' '\n' | awk '{s+=$1} END{print s+0}')"
done
(( ok )) || exit 1
partial=""
for j in ddp-a ddp-b; do
  n="$(kubectl get pods -l jobset.sigs.k8s.io/jobset-name=$j --no-headers 2>/dev/null | grep -vc Completed)"
  [[ "$n" == 1 ]] && partial+="$j "
done
check "No JobSet has only some of its workers (partial: ${partial:-none})" test -z "$partial"
wa="$(wl_of JobSet ddp-a)"; wb="$(wl_of JobSet ddp-b)"
ca="$(jp jobset.jobset.x-k8s.io/ddp-a '{.status.conditions[?(@.type=="Completed")].status}')"
cb="$(jp jobset.jobset.x-k8s.io/ddp-b '{.status.conditions[?(@.type=="Completed")].status}')"
if [[ "$ca" != True || "$cb" != True ]]; then
  ra="$(wl_cond "$wa" QuotaReserved)"; rb="$(wl_cond "$wb" QuotaReserved)"
  check "Never both admitted at once" bash -c '! [[ "$1" == True && "$2" == True && "$3" != True && "$4" != True ]]' _ "$ra" "$rb" "$ca" "$cb"
  wait_one="$( [[ "$ra" == True ]] && echo ddp-b || echo ddp-a )"
  pods="$(kubectl get pods -l jobset.sigs.k8s.io/jobset-name=$wait_one --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  check "The waiting JobSet ($wait_one) holds no pods while it waits (has $pods)" bash -c '[[ "$1" == 0 || "$2" == True ]]' _ "$pods" "$(wl_cond "$( [[ $wait_one == ddp-a ]] && echo "$wa" || echo "$wb")" QuotaReserved)"
  check "Both JobSets have completed, one after the other (about 1.5 minutes in all)" false
  exit 1
fi
check "ddp-a and ddp-b completed" true
qa="$(wl_time "$wa" QuotaReserved)"; qb="$(wl_time "$wb" QuotaReserved)"
fa="$(wl_time "$wa" Finished)"; fb="$(wl_time "$wb" Finished)"
if [[ "$qa" < "$qb" ]]; then f1="$fa"; q2="$qb"; else f1="$fb"; q2="$qa"; fi
check "The second JobSet was admitted only after the first finished (first finished $f1, second admitted $q2)" \
  bash -c '[[ -n "$1" && -n "$2" && ! "$2" < "$1" ]]' _ "$f1" "$q2"
