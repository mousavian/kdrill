source "$KDRILL_HOME/courses/inference/lib.sh"
settle llm 60 || true
A="$(jp deploy/llm '{.spec.template.spec.containers[0].args[*]}')"
ip="$(pod_ip "$(pod_names app=llm | awk '{print $1}')")"
slots="$(kx curl -s --max-time 10 http://llm/slots)"
n="$(printf '%s' "$slots" | grep -o '"id":[0-9]*' | wc -l | tr -d ' ')"
nctx="$(printf '%s' "$slots" | grep -o '"n_ctx":[0-9]*' | head -n 1 | cut -d: -f2)"
check_ge "The server has at least 4 parallel slots (got ${n:-0})" 4 "${n:-0}"
why "--parallel N (llama.cpp) / --max-num-seqs N (vLLM): how many requests are generated together in one batch."
check_ge "... each slot has a context of at least 512 tokens (got ${nctx:-0}; -c is the total, split between slots)" 512 "${nctx:-0}"
why "A 300-token prompt plus the answer needs more than 256 tokens: with -c 1024 and 4 slots each slot only has 256."
mib() { case "$1" in *Gi) echo $(( ${1%Gi} * 1024 )) ;; *Mi) echo "${1%Mi}" ;; *) echo 0 ;; esac; }
lim="$(jp deploy/llm '{.spec.template.spec.containers[0].resources.limits.memory}')"
rss="$(kubectl exec deploy/llm -- sh -c "grep VmHWM /proc/1/status" 2>/dev/null | awk '{print int($2/1024)}')"
check "The pod fits its memory limit with 15% headroom (peak ${rss:-?} MiB, limit ${lim:-?})" bash -c '[[ -n "$1" && "$1" -gt 0 ]] && (( $2 * 100 >= $1 * 115 ))' _ "${rss:-0}" "$(mib "$lim")"
check_eq "... and the limit was not raised (still 400Mi)" 400Mi "$lim"
# behaviour: 4 users at once, watch the queue while they run
tmp="$(mktemp)"
kubectl exec client -- ask -v -n 4 -c 4 -t 48 -p 'Count from one to fifty.' http://llm/v1/chat/completions > "$tmp" 2>/dev/null &
pid=$!
peak=0
for i in 1 2 3 4 5 6 7 8 9 10; do
  d="$(metric "$ip:8080" llamacpp:requests_deferred)"; d="${d%.*}"; (( ${d:-0} > peak )) && peak=${d:-0}
  sleep 0.2
done
wait "$pid" 2>/dev/null
out="$(cat "$tmp")"; rm -f "$tmp"
echo "4 users at once: $(printf '%s' "$out" | awk '{printf "%s %.1fs; ", $1, $4}')"
check_eq "4 simultaneous users: all answered 200" 4 "$(printf '%s\n' "$out" | awk '$1==200' | wc -l | tr -d ' ')"
check_eq "... and nobody waited for a slot (peak requests_deferred: $peak)" 0 "$peak"
why "llamacpp:requests_deferred counts requests waiting for a free slot (lesson 06)."
prompt="$(awk 'BEGIN{for(i=0;i<30;i++) printf "the quick brown fox jumps over the lazy dog. "}')"
big="$(ask_out -p "$prompt" -t 8 http://llm/v1/chat/completions)"
check_eq "A prompt of about 300 tokens (30 sentences) still fits in a slot and is answered" 1 "$(count_matching '^200 ' "$big")"
why "A request whose prompt does not fit in its slot's context is rejected (400): the per-slot context is -c divided by --parallel."
