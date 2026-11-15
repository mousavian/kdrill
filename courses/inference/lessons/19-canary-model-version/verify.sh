source "$KDRILL_HOME/courses/inference/lib.sh"
gw_settle edge
check_eq "HTTPRoute llm is Accepted with resolved references" "True True" "$(route_cond httproute/llm Accepted) $(route_cond httproute/llm ResolvedRefs)"
w1="$(kubectl get httproute llm -o jsonpath='{range .spec.rules[*].backendRefs[?(@.name=="v1")]}{.weight}{"\n"}{end}' 2>/dev/null | head -n 1)"
w2="$(kubectl get httproute llm -o jsonpath='{range .spec.rules[*].backendRefs[?(@.name=="v2")]}{.weight}{"\n"}{end}' 2>/dev/null | tail -n 1)"
check "A rule splits traffic between v1 and v2 by weight, v1 much heavier (weights v1=${w1:-?} v2=${w2:-?}; v1 at least 4 times v2, v2 at least 1)" \
  bash -c '[[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ && "$2" -ge 1 && "$1" -ge $(( $2 * 4 )) ]]' _ "${w1:-x}" "${w2:-x}"
why "backendRefs: - {name: v1, port: 80, weight: 90} - {name: v2, port: 80, weight: 10}"
U=http://edge/v1/chat/completions
_probe() { [[ "$(http_code $U -H 'content-type: application/json' -d '{"model":"tiny","messages":[{"role":"user","content":"hi"}],"max_tokens":4}')" == 200 ]]; }
wait_until 25 _probe || true
out="$(ask_out -n 60 -c 4 -t 4 -w 6 $U)"
v1="$(count_matching '^200 v1-' "$out")"; v2="$(count_matching '^200 v2-' "$out")"
echo "60 requests: v1=$v1 v2=$v2"
check_eq "All 60 requests answered" 60 "$((v1 + v2))"
check "About 10% went to v2: between 1 and 15 of 60 (got $v2); not all of it" bash -c '[[ "$1" -ge 1 && "$1" -le 15 ]]' _ "${v2:-0}"
why "Zero means v2 gets nothing (no canary signal), 15+ means the weights are not 90/10."
hc="$(ask_out -n 10 -t 4 -w 6 -H 'x-canary: always' $U)"
check_eq "Requests with header x-canary: always all go to v2 (10 of 10)" 10 "$(count_matching '^200 v2-' "$hc")"
why "A rule with matches: [{headers: [{name: x-canary, value: always}]}] and only v2 as backend, placed BEFORE the weighted rule."
nh="$(ask_out -n 10 -t 4 -w 6 -H 'x-canary: never' $U)"
check "A different value of the header does not force v2 (not all of 10 went to v2)" bash -c '[[ "$(echo "$1" | awk "\$2 ~ /^v2-/ {c+=\$1} END{print c+0}")" -lt 10 ]]' _ "$nh"
