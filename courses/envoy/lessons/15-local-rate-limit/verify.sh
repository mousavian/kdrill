source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics
U=http://envoy:10000

echo "/health is never limited"
out="$(hits_out -n 20 $U/health)"
check_eq "20 quick requests to /health: all 200" 20 "$(count_of "200 *" "$out")"

echo "/api/: 12 requests in a burst"
out="$(hits_out -n 12 -r x-local-rate-limit $U/api/items)"
ok="$(count_of "200 *" "$out")"; rl="$(count_of "429 true" "$out")"
check "At most 5 succeeded (got $ok)" test "$ok" -le 5
check_ge "The rest got 429 with x-local-rate-limit: true" 7 "$rl"
why "got: $(printf '%s' "$out" | tr -s ' ' | paste -sd',' -). The local_ratelimit filter in http_filters (before the router) and a token_bucket for the /api/ route."
check_ge "Envoy counted them (stat ...http_local_rate_limit.rate_limited)" 7 \
  "$(admin '/stats?filter=http_local_rate_limit.rate_limited' | awk -F': ' '{s+=$2} END{print s+0}')"
if (( rl >= 7 )); then
  echo "the bucket refills: verify waits 10.5 s, then sends 7 more"
  sleep 10.5
  out="$(hits_out -n 7 -r x-local-rate-limit $U/api/items)"
  ok="$(count_of "200 *" "$out")"
  check "5 of 7 succeed again (got $ok; 6 is possible if a refill lands mid-burst)" test "$ok" -ge 5 -a "$ok" -le 6
  why "token_bucket: {max_tokens: 5, tokens_per_fill: 5, fill_interval: 10s}"
else
  check "The bucket refills to 5 every 10 s (not tested until the burst is limited)" false
fi
