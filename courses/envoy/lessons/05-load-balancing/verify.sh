source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics
kubectl scale deploy echo --replicas=3 >/dev/null 2>&1
wait_rollout deploy/echo 60s || true
three() { [[ "$(cluster_hosts echo | wc -w | tr -d ' ')" == 3 ]]; }
wait_until 10 three || true
check_eq "Cluster echo still has the 3 echo pods as hosts" 3 "$(cluster_hosts echo | wc -w | tr -d ' ')"

echo "stickiness (8 users x 8 requests, header x-user)"
used=""; split=""
for u in alice bob carol dave erin frank grace heidi; do
  out="$(hits_out -p -n 8 http://envoy:10000/cart -H "x-user: $u")"
  w="$(whos "$out")"
  [[ "$(count_of "200 *" "$out")" == 8 && "$(echo $w | wc -w | tr -d ' ')" == 1 ]] || split+="$u($(echo $w | wc -w | tr -d ' ') pods) "
  used+="$w "
done
check_eq "Every user's 8 requests all reached one and the same pod" "" "$split"
why "hash_policy on the route: [{header: {header_name: x-user}}], and a hashing lb_policy (RING_HASH or MAGLEV) on the cluster."
distinct="$(echo $used | tr ' ' '\n' | sort -u | grep -c .)"
check_ge "The 8 users are spread over at least 2 pods" 2 "$distinct"
why "Hash something that differs per user (the x-user header), not the connection or a constant."
out="$(hits_out -n 10 http://envoy:10000/cart)"
check_eq "Requests without x-user are still served (10 x 200)" 10 "$(count_of "200 *" "$out")"
