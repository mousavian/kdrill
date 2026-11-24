source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics

echo "split (200 requests without the header)"
out="$(hits_out -n 200 http://envoy:10000/)"
v1="$(count_of "200 v1" "$out")"; v2="$(count_of "200 v2" "$out")"
check_eq "All 200 answered 200" 200 $((v1 + v2))
check "About 10% went to v2 (got $v2 of 200; accepted 6-36)" test "$v2" -ge 6 -a "$v2" -le 36
why "route.weighted_clusters: {clusters: [{name: web-v1, weight: 90}, {name: web-v2, weight: 10}]}"
check_eq "The split is done by Envoy's weighted_clusters" yes \
  "$(admin '/config_dump?resource=static_route_configs' | grep -q weighted_clusters && echo yes)"

echo "opt-in (header x-canary: always)"
out="$(hits_out -n 20 http://envoy:10000/ -H 'x-canary: always')"
check_eq "20 of 20 went to v2" 20 "$(count_of "200 v2" "$out")"
why "A route matching the header, listed before the weighted route."
out="$(hits_out -n 20 http://envoy:10000/ -H 'x-canary: never')"
check_ge "x-canary: never is not opt-in (mostly v1)" 12 "$(count_of "200 v1" "$out")"
