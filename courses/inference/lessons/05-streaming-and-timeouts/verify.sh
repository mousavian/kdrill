source "$KDRILL_HOME/courses/inference/lib.sh"
gw_settle edge
A='{.spec.template.spec.containers[0].args[*]}'
args="$(jp deploy/llm "$A")"
check "The model server is untouched (time to first token 3s, 100ms per token): fix the gateway, not the model" \
  bash -c '[[ "$1" == *"--time-to-first-token 3s"* && "$1" == *"--inter-token-latency 100ms"* ]]' _ "$args"
check_eq "Gateway edge is Programmed" True "$(gw_cond edge Programmed)"
check_eq "HTTPRoute llm is Accepted" True "$(route_cond httproute/llm Accepted)"
U=http://edge/v1/chat/completions
out="$(ask_out -s -t 30 -w 40 $U)"
code="$(printf '%s' "$out" | awk '{print $1}')"; chunks="$(printf '%s' "$out" | sed -n 's/.*chunks=\([0-9]*\).*/\1/p')"
first="$(printf '%s' "$out" | sed -n 's/.*first=\([0-9.]*\).*/\1/p')"; total="$(printf '%s' "$out" | sed -n 's/.*total=\([0-9.]*\).*/\1/p')"
echo "streamed completion, 30 tokens: $out"
check_eq "Streamed request -> 200" 200 "$code"
check_ge "... with all 30 token chunks (got ${chunks:-0})" 30 "${chunks:-0}"
why "A timeout that fires on the whole response (HTTPRoute timeouts.request) or on silence (streamIdleTimeout) truncates the stream."
check "... streamed, not buffered: the first chunk arrived ${first:-?}s in, the last ${total:-?}s in (at least 2 s later)" \
  awk -v f="${first:-0}" -v t="${total:-0}" 'BEGIN{exit !(t-f >= 2.0)}'
why "If the first byte arrives together with the last, something buffered the response."
check "... and the model's 3 s wait for the first token was not cut (first chunk after >= 2.5 s)" awk -v f="${first:-0}" 'BEGIN{exit !(f >= 2.5)}'
nstream="$(ask_out -t 12 -p 'Hello' $U)"
check_eq "A non-streamed 12-token request also works" 1 "$(count_matching '^200 ' "$nstream")"
