source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
Q='{.spec.hard.requests\.nvidia\.com/gpu}'

for ns in team-a team-b; do
  check_eq "$ns: ResourceQuota gpu-quota caps requests.nvidia.com/gpu at 4" 4 "$(jp resourcequota/gpu-quota "$Q" -n $ns)"
  why "kubectl -n $ns create quota gpu-quota --hard=requests.nvidia.com/gpu=4"
done
used="$(jp resourcequota/gpu-quota '{.status.used.requests\.nvidia\.com/gpu}' -n team-a)"
check_eq "team-a is within its quota (used requests.nvidia.com/gpu = 4)" 4 "$used"
why "A new quota does not evict running pods: team-a still holds 8. Remove the extra pods (kubectl -n team-a delete pod -l app=sweep); the ReplicaSet can only recreate 4."

check_eq "team-a sweep: exactly 4 pods Running" 4 "$(live_count Running app=sweep team-a)"
check_eq "team-a sweep still asks for 8 replicas" 8 "$(jp deploy/sweep '{.spec.replicas}' -n team-a)"
why "Scaling sweep down by hand hides the problem; the quota should enforce the share."
check_eq "team-b serve: 3 replicas, all ready" 3 "$(jp deploy/serve '{.status.readyReplicas}' -n team-b)"
why "kubectl -n team-b describe pod -l app=serve"
check_eq "GPU requests unchanged (sweep 1, serve 1)" "1 1" \
  "$(res_limit nvidia.com/gpu deploy/sweep team-a) $(res_limit nvidia.com/gpu deploy/serve team-b)"
check_eq "No other quotas in the team namespaces" "gpu-quota gpu-quota" \
  "$(kubectl get resourcequota -n team-a -o name 2>/dev/null | sed 's|.*/||') $(kubectl get resourcequota -n team-b -o name 2>/dev/null | sed 's|.*/||')"
check_eq "Still 2 nodes" 2 "$(fake_node_count)"
check_fleet_unchanged
