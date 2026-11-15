source "$KDRILL_HOME/courses/training/lib.sh"
j=shakespeare-v2
check "Job $j exists" kubectl get job $j
kubectl get job $j >/dev/null 2>&1 || exit 1
fp="$(jp job/$j '{.spec.template.spec.containers[0].env[?(@.name=="RUN_NAME")].valueFrom.fieldRef.fieldPath}')"
check "RUN_NAME comes from the Job's name label through the downward API (got ${fp:-not set})" \
  bash -c '[[ "$1" == *"batch.kubernetes.io/job-name"* || "$1" == *"job-name"* ]]' _ "$fp"
why "env: name RUN_NAME, valueFrom.fieldRef.fieldPath: metadata.labels['batch.kubernetes.io/job-name']"
check "CKPT_DIR is per run (got $(env_of job/$j CKPT_DIR))" bash -c '[[ "$1" == /ckpt/*'"'"'$(RUN_NAME)'"'"'* ]]' _ "$(env_of job/$j CKPT_DIR)"
check "MODEL_OUT is per run under /models (got $(env_of job/$j MODEL_OUT))" bash -c '[[ "$1" == /models/*'"'"'$(RUN_NAME)'"'"'* ]]' _ "$(env_of job/$j MODEL_OUT)"
k="$(env_of job/$j CKPT_KEEP)"
check "CKPT_KEEP keeps 1 or 2 checkpoints (got ${k:-default 3})" bash -c '[[ "$1" == 1 || "$1" == 2 ]]' _ "$k"
check_eq "STEPS 600 and CKPT_EVERY 50 are unchanged" "600 50" "$(env_of job/$j STEPS) $(env_of job/$j CKPT_EVERY)"
tt="$(jp job/$j '{.spec.ttlSecondsAfterFinished}')"
check "ttlSecondsAfterFinished between 300 and 86400 (got ${tt:-unset})" bash -c '[[ "$1" =~ ^[0-9]+$ && $1 -ge 300 && $1 -le 86400 ]]' _ "$tt"
st="$(job_state $j)"
if [[ "$st" == running || "$st" == pending ]]; then
  check "Job $j has finished ($(progress_msg $j); about 30 s)" false
  exit 1
fi
check_eq "Job $j completed" complete "$st"
inspect_up checkpoints models
d=/mnt/checkpoints/$j
check_eq "v2 trained from scratch into its own directory (checkpoints/$j/metrics.json: first start step, status, step)" "0 done 600" \
  "$(mget $d/metrics.json runs.0.start_step status step | paste -sd' ' -)"
n="$(ix sh -c "ls $d/ckpt-*.pt 2>/dev/null | wc -l" | tr -d ' ')"
check "At most 2 checkpoints of v2 are kept (found ${n:-0})" bash -c '[[ "$1" -ge 1 && "$1" -le 2 ]]' _ "${n:-0}"
check_eq "shakespeare-v1's results are untouched (checkpoints/metrics.json run_name, step; ckpt-000600.pt)" "shakespeare-v1 600 yes" \
  "$(mget /mnt/checkpoints/metrics.json run_name step | paste -sd' ' -) $(ix test -f /mnt/checkpoints/ckpt-000600.pt && echo yes)"
why "Don't delete another run's results to make yours work."
check_eq "The model artifact exists with its metadata (models/$j/model.json: run_name, steps)" "$j 600" \
  "$(mget /mnt/models/$j/model.json run_name steps | paste -sd' ' -)"
check "models/$j/model.pt exists" ix test -s /mnt/models/$j/model.pt
inspect_down
check "Job sample exists" kubectl get job sample
if kubectl get job sample >/dev/null 2>&1; then
  check_eq "Job sample completed" complete "$(job_state sample)"
  why "Run it after $j is complete: kubectl delete job sample; kubectl apply -f manifests/sample.yaml"
  check "It sampled from the v2 model (/models/$j/model.pt)" bash -c '[[ "$1" == *"sample from /models/'"$j"'/model.pt"* ]]' _ "$(job_logs sample)"
fi
