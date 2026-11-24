source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
check_eq "HTTPRoute web is Accepted with ResolvedRefs" "True True" "$(route_cond httproute/web Accepted) $(route_cond httproute/web ResolvedRefs)"
echo "split (200 requests to www.lab)"
out="$(hits_out -n 200 http://edge/ -H 'Host: www.lab')"
v1="$(count_of "200 v1" "$out")"; v2="$(count_of "200 v2" "$out")"
check_eq "All 200 answered 200" 200 $((v1 + v2))
check "About 10% went to v2 (got $v2; accepted 6-36)" test "$v2" -ge 6 -a "$v2" -le 36
why "backendRefs: [{name: web-v1, port: 80, weight: 90}, {name: web-v2, port: 80, weight: 10}]"
w="$(kubectl get httproute web -o jsonpath='{range .spec.rules[*].backendRefs[*]}{.name}={.weight}{" "}{end}' 2>/dev/null)"
check "The split comes from backendRef weights in the HTTPRoute (got: ${w:-none})" eval '[[ " $w " == *" web-v1=90 "* && " $w " == *" web-v2=10 "* ]]'
echo "opt-in"
out="$(hits_out -n 20 http://edge/ -H 'Host: www.lab' -H 'x-canary: always')"
check_eq "x-canary: always -> 20 of 20 to v2" 20 "$(count_of "200 v2" "$out")"
why "A second rule with a header match; it is more specific than the rule without matches, so it wins."
out="$(hits_out -n 20 http://edge/ -H 'Host: www.lab' -H 'x-canary: never')"
check_ge "x-canary: never is not opt-in (mostly v1)" 12 "$(count_of "200 v1" "$out")"
