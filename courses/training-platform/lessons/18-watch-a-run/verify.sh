source "$KDRILL_HOME/courses/training-platform/lib.sh"
check "Job train exists" kubectl get job train
kubectl get job train >/dev/null 2>&1 || exit 1
check_eq "STEPS is still 3000" 3000 "$(env_of job/train STEPS)"
c='{.spec.template.spec.containers[0]'
lim="$(jp job/train "$c.resources.limits.cpu}")"; req="$(jp job/train "$c.resources.requests.cpu}")"
lm="$(cpu_millis "$lim")"
check "CPU limit is 1-2 cores (got ${lim:-none})" bash -c '[[ "$1" -ge 1000 && "$1" -le 2000 ]]' _ "$lm"
why "A limit below one core throttles a single training thread for most of every 100 ms period."
check "CPU request is set and not above the limit (got ${req:-none})" bash -c '[[ -n "$1" && "$2" -le "$3" && "$2" -gt 0 ]]' _ "$req" "$(cpu_millis "$req")" "$lm"
check_eq "Service train-metrics exists" train-metrics "$(jp svc/train-metrics '{.metadata.name}')"
st="$(job_state train)"
if [[ "$st" != running ]]; then
  check "Job train is running, so verify can scrape it (state: $st; re-create it if it already finished)" false
  exit 1
fi
eps="$(kubectl get endpointslices -l kubernetes.io/service-name=train-metrics -o jsonpath='{.items[*].endpoints[*].addresses[*]}' 2>/dev/null)"
check "Service train-metrics has the training pod behind it" test -n "$eps"
why "Its selector must match the Job's pod labels (e.g. batch.kubernetes.io/job-name: train) and its port the metrics port."
inspect_up
scrape() { ix python3 -c "import urllib.request; print(urllib.request.urlopen('http://train-metrics:9090/metrics', timeout=5).read().decode())"; }
metric() { printf '%s\n' "$1" | awk -v n="$2" '$1==n {print $2}'; }
m1="$(scrape)"
check "http://train-metrics:9090/metrics answers in Prometheus format" bash -c '[[ "$1" == *"# TYPE kdrill_train_step gauge"* ]]' _ "$m1"
why "METRICS_PORT=9090 in the container, and the Service's targetPort pointing at 9090."
s1="$(metric "$m1" kdrill_train_step)"
up() { [[ "$(metric "$(scrape)" kdrill_train_step)" -gt "${s1:-0}" ]] 2>/dev/null; }
wait_until 20 up || true
m2="$(scrape)"; s2="$(metric "$m2" kdrill_train_step)"
check "kdrill_train_step goes up between two scrapes (${s1:-?} -> ${s2:-?})" bash -c '[[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[0-9]+$ && $2 -gt $1 ]]' _ "${s1:-}" "${s2:-}"
tps="$(metric "$m2" kdrill_train_tokens_per_second)"; base="$(baseline_get tps)"
if [[ "$(baseline_get enforced)" == yes ]]; then
  check "It trains at least 2.5x faster than before (${tps:-?} tokens/s now, ${base:-?} at the start)" \
    awk -v a="${tps:-0}" -v b="${base:-0}" 'BEGIN{exit !(b > 0 && a >= 2.5*b)}'
  why "Look at the CPU limit, and at OMP_NUM_THREADS compared to it."
else
  info "(speed check skipped: this node did not enforce the 250m CPU limit at setup, so there was no slowdown to fix; ${tps:-?} tokens/s now, ${base:-?} before)"
fi
thr="$(metric "$m2" kdrill_train_threads)"
check_eq "PyTorch threads equal the CPU limit (kdrill_train_threads)" "$(( (lm + 999) / 1000 ))" "${thr:-?}"
inspect_down
