source "$KDRILL_HOME/courses/training/lib.sh"
check "Job train exists" kubectl get job train
kubectl get job train >/dev/null 2>&1 || exit 1
mp="$(jp job/train '{range .spec.template.spec.containers[0].volumeMounts[*]}{.name}={.mountPath}{"\n"}{end}')"
dir="$(env_of job/train CKPT_DIR)"
vol="$(printf '%s\n' "$mp" | awk -F= -v p="$dir" '$2==p || index(p, $2"/")==1 {print $1}' | head -n 1)"
check_eq "The checkpoint directory ${dir:-?} is on the PVC checkpoints" checkpoints \
  "$(jp job/train "{.spec.template.spec.volumes[?(@.name==\"$vol\")].persistentVolumeClaim.claimName}")"
why "An emptyDir is deleted with its pod. Mount persistentVolumeClaim checkpoints at the CKPT_DIR path."
ce="$(env_of job/train CKPT_EVERY)"
check "Job train still checkpoints every 100 steps or more often (CKPT_EVERY=${ce:-default 100})" bash -c '[[ -z "$1" || ( "$1" =~ ^[0-9]+$ && $1 -le 100 && $1 -ge 1 ) ]]' _ "$ce"
st="$(job_state train)"
if [[ "$st" == running || "$st" == pending ]]; then
  check "Job train has finished (still running, $(progress_msg train); about 30 s)" false
  why "Wait, then run the sample Job and verify again."
  exit 1
fi
check_eq "Job train completed" complete "$st"
inspect_up checkpoints
status="$(mget /mnt/checkpoints/metrics.json status step)"
check_eq "The volume holds the finished run (metrics.json status and step)" "done 600" "$(echo $status)"
why "kubectl logs job/train; the run must write CKPT_DIR on the PVC and train 600 steps."
check_eq "The newest checkpoint on the volume is from step 600" 600 "$(ix mlt ckpt /mnt/checkpoints)"
n="$(ix sh -c 'ls /mnt/checkpoints/ckpt-*.pt 2>/dev/null | wc -l' | tr -d ' ')"
check_ge "Several checkpoints were kept on the volume (found ${n:-0})" 2 "${n:-0}"
inspect_down
check "Job sample exists" kubectl get job sample
if kubectl get job sample >/dev/null 2>&1; then
  check_eq "Job sample mounts the PVC checkpoints" checkpoints "$(jp job/sample '{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}')"
  check_eq "Job sample completed" complete "$(job_state sample)"
  why "kubectl logs job/sample. Create it only after train is Complete (delete the old one first)."
  slog="$(job_logs sample)"
  from="$(printf '%s\n' "$slog" | sed -n 's/^--- sample from \([^ ]*\) (step \([0-9]*\).*/\1 \2/p' | head -n 1)"
  check_eq "It sampled from the final checkpoint (step 600)" 600 "${from#* }"
  why "A sample Job that ran while training was still going reads an older checkpoint: run it after train completes."
  check "It printed generated text" bash -c '[[ $(printf "%s\n" "$1" | sed -n "2,\$p" | wc -c) -gt 100 ]]' _ "$slog"
fi
