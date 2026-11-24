source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics
kubectl scale deploy echo --replicas=3 >/dev/null 2>&1
wait_rollout deploy/echo 60s || true

hosts_ok() { [[ "$(cluster_hosts echo | sed 's/:80//g')" == "$(pod_ips app=echo)" ]]; }
budget=25; wait_until 10 hosts_ok || budget=5   # far from done: don't wait long below
echo "discovery (admin /clusters)"
check_eq "Cluster echo has one host per echo pod (pod IPs, port 80)" "$(pod_ips app=echo | sed 's/\([0-9.]*\)/\1:80/g')" "$(cluster_hosts echo)"
why "A ClusterIP Service resolves to one virtual IP. A headless Service (clusterIP: None) resolves to every ready pod's IP."

echo "balancing (30 requests, which pod answered)"
out="$(hits_out -p -n 30 http://envoy:10000/)"
pods="$(printf '%s\n' "$out" | awk '$2==200' | wc -l | tr -d ' ')"
low="$(printf '%s\n' "$out" | awk '$2==200 {print $1}' | sort -n | head -n 1)"
check_eq "All 3 echo pods answered" 3 "$pods"
check_ge "Each pod got at least 6 of the 30 requests (Envoy round robin)" 6 "${low:-0}"
why "got: $(printf '%s' "$out" | tr -s ' ' | paste -sd',' -)"

echo "dynamic: verify scales echo to 4 replicas"
kubectl scale deploy echo --replicas=4 >/dev/null
wait_rollout deploy/echo 60s || true
four() { [[ "$(cluster_hosts echo | wc -w | tr -d ' ')" == 4 ]] && hosts_ok; }
t0=$SECONDS; wait_until $budget four; ok=$?
check "Envoy picked up the 4th pod within 25 s (took $((SECONDS - t0)) s)" test "$ok" = 0
why "STRICT_DNS re-resolves every dns_refresh_rate (default 5 s); the headless Service's DNS answer changes when a pod becomes ready."
kubectl scale deploy echo --replicas=3 >/dev/null
