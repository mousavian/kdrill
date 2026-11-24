source "$KDRILL_HOME/courses/inference/lib.sh"
gw_settle edge
check_eq "Gateway edge is Programmed" True "$(gw_cond edge Programmed)"
check_eq "HTTPRoute llm is Accepted with resolved references" "True True" "$(route_cond httproute/llm Accepted) $(route_cond httproute/llm ResolvedRefs)"
U=http://edge/v1/chat/completions
who_is() { printf '%s' "$1" | awk '{print $2}' | cut -c1-5; }
# a policy that extracts the model name from the body must exist and be accepted
eep="$(kubectl get envoyextensionpolicy -o jsonpath='{range .items[*]}{.status.ancestors[0].conditions[?(@.type=="Accepted")].status}{" "}{.spec.lua[0].type}{"\n"}{end}' 2>/dev/null | head -n 1)"
check "An EnvoyExtensionPolicy with a Lua filter is attached to the Gateway and Accepted (got: ${eep:-none})" bash -c '[[ "$1" == "True Inline"* ]]' _ "$eep"
why "kubectl explain envoyextensionpolicy.spec.lua; the policy must target the Gateway (it has to run before the route is chosen)."
_wait_lua() { [[ "$(kx curl -s -o /dev/null -w '%{http_code}' --max-time 10 $U -H 'content-type: application/json' -d '{"model":"large","messages":[{"role":"user","content":"hi"}],"max_tokens":4}')" == 200 ]]; }
wait_until 25 _wait_lua || true
s="$(ask_out -m small -n 12 -c 3 $U)"; l="$(ask_out -m large -n 6 -c 2 $U)"
check_eq "model small: 12 of 12 answered 200 by the small servers" 12 "$(count_matching '^200 small' "$s")"
check_eq "model large: 6 of 6 answered 200 by the large server" 6 "$(count_matching '^200 large' "$l")"
why "A rule per model: matches headers x-model=small / x-model=large to the Services small / large; the Lua filter sets x-model from the body."
sp="$(ask_out -m small -n 6 -H 'x-model: large' $U)"
check_eq "A client-supplied x-model: large header with model small in the body is ignored (6 of 6 still served by small)" 6 "$(count_matching '^200 small' "$sp")"
why "Overwrite the header (headers():replace), never trust or append to it: otherwise clients choose their own backend."
un="$(ask_out -m nope -n 3 $U)"
check_eq "An unknown model gets 404 from the gateway itself (3 of 3; not forwarded to a model server)" 3 "$(count_matching '^404 -$' "$un")"
why "A last catch-all rule with a direct response (HTTPRouteFilter directResponse 404). Without any catch-all, Envoy Gateway never runs the Lua filter: it is enabled per matched route."
st="$(ask_out -s -m large -t 12 -w 20 $U)"
chunks="$(printf '%s' "$st" | sed -n 's/.*chunks=\([0-9]*\).*/\1/p')"; first="$(printf '%s' "$st" | sed -n 's/.*first=\([0-9.]*\).*/\1/p')"; total="$(printf '%s' "$st" | sed -n 's/.*total=\([0-9.]*\).*/\1/p')"
check "A streamed request for the large model still streams (200, ${chunks:-0} chunks, first at ${first:-?}s, last at ${total:-?}s)" \
  bash -c '[[ "$(echo "$1" | cut -d" " -f1)" == 200 && "${2:-0}" -ge 12 ]] && awk -v f="${3:-0}" -v t="${4:-0}" "BEGIN{exit !(t-f >= 0.3)}"' _ "$st" "$chunks" "$first" "$total"
why "Only the REQUEST body is buffered (to read the model name); the response must pass through unbuffered."
check "The Services still select their own pods (small -> app=small, large -> app=large): no shortcuts" \
  bash -c '[[ "$(kubectl get svc small -o jsonpath="{.spec.selector.app}")" == small && "$(kubectl get svc large -o jsonpath="{.spec.selector.app}")" == large ]]'
