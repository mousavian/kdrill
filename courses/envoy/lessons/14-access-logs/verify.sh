source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics
run="v$RANDOM$RANDOM"
send() { http_code "http://envoy:10000$1" -H "x-request-id: $run-$2" >/dev/null; }
send /app/ok ok
send /nothing/here noroute
send /down/x down
send '/app/slow?wait=3s' slow
logline() { kubectl logs deploy/envoy --since=120s 2>/dev/null | grep -F "\"$run-$1\"" | tail -n 1; }
seen() { [[ -n "$(logline "$1")" ]]; }
all_seen() { seen noroute && seen down && seen slow; }
wait_until 12 all_seen || true   # each worker thread flushes its own log buffer

echo "log lines (kubectl logs deploy/envoy) for 4 requests verify just sent"
# field LINE KEY -> raw JSON value (numbers bare, strings without quotes)
field() { printf '%s' "$1" | grep -o "\"$2\":[^,}]*" | head -n 1 | cut -d: -f2- | tr -d '"'; }
for c in noroute:404:NR down:503:UH slow:504:UT; do
  id="${c%%:*}"; rest="${c#*:}"; code="${rest%%:*}"; flag="${rest#*:}"
  l="$(logline "$id")"
  check "A JSON line for the $code ($flag) request" test -n "$l" -a "${l:0:1}" = "{"
  why "access_log on the HCM: envoy.access_loggers.stdout with log_format.json_format"
  [[ -n "$l" ]] || continue
  check_eq "... status $code, flags $flag, method GET" "$code $flag GET" "$(field "$l" status) $(field "$l" flags) $(field "$l" method)"
  why "keys: status (%RESPONSE_CODE%), flags (%RESPONSE_FLAGS%), method (%REQ(:METHOD)%)"
done
l="$(logline slow)"
if [[ -n "$l" ]]; then
  check_eq "The timeout line has path /app/slow?wait=3s" "/app/slow?wait=3s" "$(field "$l" path)"
  check "... upstream = the host Envoy picked in cluster web ($(cluster_hosts web))" eval '[[ "$(field "$l" upstream)" == "$(cluster_hosts web)" ]]'
  why "upstream: %UPSTREAM_HOST%"
  d="$(field "$l" duration_ms)"
  check "... duration_ms is a number of about 1000 (got ${d:-nothing})" awk -v d="$d" 'BEGIN{exit !(d ~ /^[0-9]+$/ && d>=900 && d<2000)}'
  check_eq "... request_id is the client's x-request-id" "$run-slow" "$(field "$l" request_id)"
fi
check_eq "The successful request (200) was NOT logged" "" "$(logline ok)"
why "filter: {status_code_filter: {comparison: {op: GE, value: {default_value: 400, runtime_key: ...}}}}"
