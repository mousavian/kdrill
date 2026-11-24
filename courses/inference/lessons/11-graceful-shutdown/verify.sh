source "$KDRILL_HOME/courses/inference/lib.sh"
P='{.spec.template.spec'
grace="$(jp deploy/llm "$P.terminationGracePeriodSeconds}")"
ps="$(jp deploy/llm "$P.containers[0].lifecycle.preStop.sleep.seconds}")"
pe="$(jp deploy/llm "$P.containers[0].lifecycle.preStop.exec.command[*]}")"
if [[ -z "$ps" && "$pe" =~ sleep\ ([0-9]+) ]]; then ps="${BASH_REMATCH[1]}"; fi
check "A preStop hook delays SIGTERM by at least 6 s (preStop sleep: ${ps:-none})" bash -c '[[ "$1" =~ ^[0-9]+$ && "$1" -ge 6 ]]' _ "${ps:-x}"
why "While preStop runs the container keeps serving; meanwhile the endpoint is removed from the Service. kubectl explain pod.spec.containers.lifecycle.preStop.sleep"
check "terminationGracePeriodSeconds covers preStop plus the longest request (>= preStop + 8 s: ${grace:-?} vs ${ps:-?}+8)" bash -c '[[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ && "$1" -ge $(( $2 + 8 )) ]]' _ "${grace:-x}" "${ps:-x}"
why "The grace period is the TOTAL budget from the delete until SIGKILL: preStop time counts against it."
check "The model is unchanged (answers take about 4.5 s: ttft 500ms, 200ms per token)" bash -c '[[ "$1" == *"--inter-token-latency 200ms"* ]]' _ "$(jp deploy/llm "$P.containers[0].args[*]}")"
settle llm 60 || true
# behaviour: 6 users, ~36 requests, a rollout in the middle of it
o="$(mktemp)"
kubectl exec client -- ask -n 36 -c 6 -t 20 -w 25 http://llm/v1/chat/completions > "$o" 2>/dev/null &
loadpid=$!
sleep 6
kubectl rollout restart deploy/llm >/dev/null 2>&1
kubectl rollout status deploy/llm --timeout=90s >/dev/null 2>&1
wait "$loadpid" 2>/dev/null
out="$(cat "$o")"; rm -f "$o"
ok="$(count_matching '^200 ' "$out")"; total="$(printf '%s\n' "$out" | awk '{t+=$1} END{print t+0}')"
echo "rollout during traffic: $(printf '%s' "$out" | tr '\n' ';')"
check_eq "All 36 requests sent during a rollout restart answered 200 (answered: $ok of ${total:-0})" 36 "$ok"
why "Failures (000, 502, 503) mean a request was cut by SIGKILL or sent to a pod that had already stopped listening."
check_eq "Both replicas are ready again after the rollout" 2 "$(ready_pods app=llm)"
