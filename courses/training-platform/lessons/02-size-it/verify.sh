source "$KDRILL_HOME/courses/training-platform/lib.sh"
check "Job train exists" kubectl get job train
why "kubectl apply -f your fixed job.yaml"
kubectl get job train >/dev/null 2>&1 || exit 1
c='{.spec.template.spec.containers[0]'
mem_lim="$(jp job/train "$c.resources.limits.memory}")"
check_eq "Memory limit is still 768Mi (that is the budget)" 768Mi "$mem_lim"
why "Bring the memory use down instead of raising the limit."
check "Memory request is set (at least 384Mi, at most the limit)" bash -c \
  'case "$1" in *Mi) v=${1%Mi};; *Gi) v=$(( ${1%Gi} * 1024 ));; *) exit 1;; esac; (( v >= 384 && v <= 768 ))' _ "$(jp job/train "$c.resources.requests.memory}")"
cpu_req="$(jp job/train "$c.resources.requests.cpu}")"; cpu_lim="$(jp job/train "$c.resources.limits.cpu}")"
check "CPU request and CPU limit are set (limit at most 2 cores)" bash -c '[[ -n "$1" && -n "$2" ]] && (( $3 <= 2000 && $3 >= $4 ))' _ "$cpu_req" "$cpu_lim" "$(cpu_millis "$cpu_lim")" "$(cpu_millis "$cpu_req")"
st="$(job_state train)"
if [[ "$st" == running || "$st" == pending ]]; then
  check "Job train has finished (still running, $(progress_msg train); about 20-40 s)" false
  why "Wait and run kdrill verify again: kubectl get pods -w"
  exit 1
fi
codes="$(exit_codes train)"
check "No pod of the current Job was OOMKilled (seen: ${codes:-none})" bash -c '[[ "$1" != *OOMKilled* ]]' _ "$codes"
why "kubectl describe pod -l batch.kubernetes.io/job-name=train: Reason OOMKilled means over the memory limit."
check_eq "Job train completed" complete "$st"
logs="$(job_logs train)"
steps="$(printf '%s\n' "$logs" | sed -n 's/.*done: step \([0-9]*\) .*/\1/p' | tail -n 1)"
check_ge "It trained all 300 steps (done: step ${steps:-?})" 300 "${steps:-0}"
loss="$(final_loss "$logs")"
check "The final loss is below 2.9 (got ${loss:-none})" float_lt "$loss" 2.9
threads="$(printf '%s\n' "$logs" | sed -n 's/.* threads=\([0-9]*\) .*/\1/p' | head -n 1)"
want="$(( ( $(cpu_millis "$cpu_lim") + 999 ) / 1000 ))"
check_eq "PyTorch used as many threads as the CPU limit (rounded up) allows (logged threads=${threads:-?})" "$want" "${threads:-?}"
why "Set OMP_NUM_THREADS to the CPU limit (valueFrom.resourceFieldRef limits.cpu, divisor 1)."
