source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics
kubectl scale deploy echo --replicas=3 >/dev/null 2>&1
wait_rollout deploy/echo 60s || true

# The 3 echo pods as "name ip" lines, and their /health set back to 200.
pods="$(kubectl get pods -l app=echo --field-selector=status.phase=Running --no-headers \
  -o custom-columns=N:.metadata.name,IP:.status.podIP,D:.metadata.deletionTimestamp | awk '$3=="<none>"{print $1, $2}' | sort)"
sethealth() { kx curl -s -X POST -d "$2" "http://$1/health" >/dev/null; }
for ip in $(echo "$pods" | awk '{print $2}'); do sethealth "$ip" 200; done
three() { [[ "$(cluster_hosts echo | wc -w | tr -d ' ')" == 3 ]]; }
wait_until 10 three || true
check_eq "Cluster echo has the 3 echo pods as hosts" 3 "$(cluster_hosts echo | wc -w | tr -d ' ')"
flags_of() { host_flags echo "$1:80"; }
allhealthy() { local ip; for ip in $(echo "$pods" | awk '{print $2}'); do [[ "$(flags_of "$ip")" == healthy ]] || return 1; done; }
wait_until 8 allhealthy || true

p1="$(echo "$pods" | sed -n 1p)"; p2="$(echo "$pods" | sed -n 2p)"; p3="$(echo "$pods" | sed -n 3p)"
n1="${p1% *}"; ip1="${p1#* }"; n2="${p2% *}"; ip2="${p2#* }"; n3="${p3% *}"

echo "one pod gets sick (verify POSTs 500 to its /health)"
sethealth "$ip1" 500
failed1() { [[ "$(flags_of "$ip1")" == *failed_active_hc* ]]; }
t0=$SECONDS; wait_until 8 failed1; ok=$?
check "Envoy marked $n1 unhealthy (/failed_active_hc) within 8 s (took $((SECONDS - t0)) s)" test $ok = 0
why "Probe the real health endpoint (/health; whoami answers 200 on any other path) every 1-2 s, with unhealthy_threshold 2-3."
# The worker threads' load balancers follow the health flags a moment later.
avoids() { [[ "$(count_of "* $1" "$(hits_out -p -n 6 http://envoy:10000/)")" == 0 ]]; }
(( ok == 0 )) && wait_until 4 avoids "$n1"
out="$(hits_out -p -n 30 http://envoy:10000/)"
check_eq "30 requests: all 200, none to $n1" "30 0" "$(count_of "200 *" "$out") $(count_of "* $n1" "$out")"

echo "most pods get sick (a second pod fails too)"
sethealth "$ip2" 500
failed2() { [[ "$(flags_of "$ip2")" == *failed_active_hc* ]]; }
wait_until 8 failed2 && wait_until 4 avoids "$n2"
out="$(hits_out -p -n 30 http://envoy:10000/)"
check_eq "30 requests: all 200, all from the last healthy pod $n3" 30 "$(count_of "200 $n3" "$out")"
why "With only 1 of 3 hosts healthy (< 50%), Envoy enters panic mode and balances over ALL hosts. common_lb_config.healthy_panic_threshold: {value: 0} turns that off."

echo "recovery (both pods' /health back to 200)"
sethealth "$ip1" 200; sethealth "$ip2" 200
t0=$SECONDS; wait_until 8 allhealthy; ok=$?
check "Envoy marked both pods healthy again within 8 s (took $((SECONDS - t0)) s)" test $ok = 0
allthree() { [[ "$(whos "$(hits_out -p -n 9 http://envoy:10000/)" | wc -w | tr -d ' ')" == 3 ]]; }
(( ok == 0 )) && wait_until 4 allthree
out="$(hits_out -p -n 30 http://envoy:10000/)"
check_eq "30 requests reach all 3 pods again" 3 "$(whos "$out" | wc -w | tr -d ' ')"
