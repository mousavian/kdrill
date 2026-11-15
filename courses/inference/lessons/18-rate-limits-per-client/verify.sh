source "$KDRILL_HOME/courses/inference/lib.sh"
gw_settle edge
U=http://edge/v1/chat/completions
R='{.items[0].spec.rateLimit'
rl="$(kubectl get backendtrafficpolicy -o jsonpath="{range .items[*]}{.spec.targetRefs[0].kind}/{.spec.targetRefs[0].name}:{.spec.rateLimit.type}:{.spec.rateLimit.local.rules[0].clientSelectors[0].headers[0].name}:{.spec.rateLimit.local.rules[0].clientSelectors[0].headers[0].type}:{.spec.rateLimit.local.rules[0].limit.requests}/{.spec.rateLimit.local.rules[0].limit.unit}:{.status.ancestors[0].conditions[?(@.type==\"Accepted\")].status}{\"\n\"}{end}" 2>/dev/null | grep -v '^:' | head -n 1)"
check "A BackendTrafficPolicy on HTTPRoute llm: local rate limit, Distinct values of the x-api-key header, Accepted (got: ${rl:-none})" \
  bash -c '[[ "$1" == "HTTPRoute/llm:Local:x-api-key:Distinct:"*":True" ]]' _ "$rl"
why "rateLimit: {type: Local, local: {rules: [{clientSelectors: [{headers: [{name: x-api-key, type: Distinct}]}], limit: {requests: N, unit: Second}}]}} - Distinct = one bucket per key value."
lim="$(printf '%s' "$rl" | cut -d: -f5 | cut -d/ -f1)"; unit="$(printf '%s' "$rl" | cut -d: -f5 | cut -d/ -f2)"
check "The limit is between 1 and 3 requests per Second (got ${lim:-?}/${unit:-?}): small enough to leave the model's 2 slots to others" bash -c '[[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 3 && "$2" == Second ]]' _ "${lim:-x}" "${unit:-x}"
why "The model runs 2 requests at once, 0.7 s each: at most about 3 requests per second per key keeps one key from taking both slots all the time."
_ok() { [[ "$(kx curl -s -o /dev/null -w '%{http_code}' --max-time 10 $U -H 'content-type: application/json' -H 'x-api-key: probe' -d '{"model":"tiny","messages":[{"role":"user","content":"hi"}],"max_tokens":4}')" != 000 ]]; }
wait_until 25 _ok || true
sleep 3
m="$(ask_out -n 24 -c 24 -t 4 -w 6 -H 'x-api-key: mallory' $U)"
m429="$(count_matching '^429 ' "$m")"
check_ge "Mallory, sending 24 requests at once, is throttled: at least 14 of them got 429 (got $m429)" 14 "$m429"
a="$(ask_out -v -n 6 -t 10 -w 14 -H 'x-api-key: alice' $U)"
a200="$(count_matching '^200 ' "$(printf '%s\n' "$a" | awk '{print $1, $2, $2}' | sort | uniq -c | awk '{print $1, $2, $3}')")"
echo "alice (one request after another, while mallory is flooding): $(printf '%s' "$a" | awk '{printf "%s %.1fs; ", $1, $4}')"
check_eq "Alice's 6 requests all answered 200 (she is under her own budget)" 6 "${a200:-0}"
med="$(printf '%s\n' "$a" | awk '{print $4}' | sort -n | sed -n 3p)"
check "... with a median response time of at most 1.6 s (got ${med:-?} s; alone the model needs 0.7 s)" awk -v m="${med:-99}" 'BEGIN{exit !(m <= 1.6)}'
why "Without a limit mallory's 8 users keep both model slots busy and alice waits in the queue."
nk="$(ask_out -n 5 -t 4 -w 6 $U)"
check_eq "Requests without an API key are not rejected by the limit (5 of 5 answered)" 5 "$(count_matching '^200 ' "$nk")"
