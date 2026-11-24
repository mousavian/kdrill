source "$KDRILL_HOME/courses/inference/lib.sh"
settle llm 60 || true
ARGS="$(jp deploy/llm '{.spec.template.spec.containers[0].args[*]}')"
check "The model server still has one slot (--parallel 1) and the users still send 3 concurrent requests" bash -c '[[ "$1" == *"--parallel 1"* && "$2" == *"-c 3"* ]]' _ "$ARGS" "$(jp deploy/users '{.spec.template.spec.containers[0].command[*]}')"
why "The lesson is about reading the server's state, not about changing the load."
ip="$(pod_ip "$(pod_names app=llm | awk '{print $1}')")"
body="$(kx curl -s --max-time 5 "http://$ip:8080/metrics")"
check "The server exposes /metrics (llama.cpp needs the --metrics flag)" bash -c '[[ "$1" == *"llamacpp:requests_processing"* ]]' _ "$body"
why "Without the flag /metrics answers an error. Add --metrics to the server arguments."
F() { jp cm/findings "{.data.$1}"; }
check_eq "findings.waiting-metric: the gauge that counts requests waiting for a free slot" "llamacpp:requests_deferred" "$(F waiting-metric)"
why "kubectl exec client -- curl -s http://<pod-ip>:8080/metrics | grep -E 'HELP|^llamacpp'  (HELP lines explain each metric)"
check_eq "findings.running-metric: the gauge that counts requests being generated" "llamacpp:requests_processing" "$(F running-metric)"
check_eq "findings.tokens-metric: the counter of generated tokens (rate() of it is tokens/s)" "llamacpp:tokens_predicted_total" "$(F tokens-metric)"
_q() { [[ "$(metric "$ip:8080" llamacpp:requests_deferred)" -ge 1 ]]; }
wait_until 30 _q || true   # after a restart the users need a moment to come back
# live values: median of 5 samples of requests_deferred over ~4 s, and tokens/s over 8 s
d=""; for i in 1 2 3 4 5; do d="$d $(metric "$ip:8080" llamacpp:requests_deferred)"; sleep 1; done
live_q="$(printf '%s\n' $d | sort -n | sed -n 3p)"
t0="$(metric "$ip:8080" llamacpp:tokens_predicted_total)"; sleep 8; t1="$(metric "$ip:8080" llamacpp:tokens_predicted_total)"
live_tps="$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%d", (b-a)/8}')"
echo "live now: $live_q request(s) waiting, about $live_tps generated tokens/s"
q="$(F queue-depth)"; tps="$(F tokens-per-second)"
check "findings.queue-depth = requests waiting right now (yours: ${q:-none}, live: $live_q)" bash -c '[[ "$1" =~ ^[0-9]+$ ]] && (( $1 - $2 <= 1 && $2 - $1 <= 1 ))' _ "${q:-x}" "$live_q"
why "Three users, one slot: one request runs, the others wait. Read llamacpp:requests_deferred while the load runs."
check "findings.tokens-per-second is within a factor of two of the real generation rate (yours: ${tps:-none}, live: $live_tps)" \
  bash -c '[[ "$1" =~ ^[0-9]+$ && "$2" -gt 0 ]] && (( $1 * 100 >= $2 * 50 && $1 * 100 <= $2 * 200 ))' _ "${tps:-x}" "$live_tps"
why "Read the counter llamacpp:tokens_predicted_total twice, N seconds apart: (second - first) / N."
