source "$KDRILL_HOME/courses/training-platform/lib.sh"
check "PVC dataset exists" kubectl get pvc dataset
why "A PersistentVolumeClaim named dataset (storageClassName local-path)."
check "Job train exists" kubectl get job train
kubectl get job train >/dev/null 2>&1 || exit 1
claims=" $(jp job/train '{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}') "
check "Job train mounts PVC dataset" bash -c '[[ "$1" == *" dataset "* ]]' _ "$claims"
check "Job train no longer uses the ConfigMap corpus" bash -c '[[ " $1 " != *" corpus "* ]]' _ "$(jp job/train '{.spec.template.spec.volumes[*].configMap.name}')"
st="$(job_state train)"
if [[ "$st" == running || "$st" == pending ]]; then
  check "Job train has finished (still running, $(progress_msg train); about 30 s)" false
  why "Wait and verify again. If the pod is Init:Error: kubectl logs job/train -c <init container>"
  exit 1
fi
check_eq "Job train completed" complete "$st"
logs="$(job_logs train train)"
data="$(printf '%s\n' "$logs" | sed -n 's/.* data=\([^ ]*\) chars=\([0-9]*\) .* prepared=\([a-z]*\).*/\1 \2 \3/p' | head -n 1)"
set -- $data
check_ge "It trained on the whole corpus (logged chars=${2:-?})" 1000000 "${2:-0}"
check_eq "The data was prepared (meta.json next to input.txt, logged prepared=${3:-?})" yes "${3:-}"
why "Point DATA at the directory prepare wrote, e.g. DATA=/data"
mp="$(jp job/train '{range .spec.template.spec.containers[0].volumeMounts[*]}{.name}={.mountPath}{"\n"}{end}')"
vol="$(printf '%s\n' "$mp" | awk -F= -v p="${1:-/nonexistent}" 'index(p, $2"/")==1 {print $1}' | head -n 1)"
check_eq "The data file is on the PVC dataset (path ${1:-?})" dataset \
  "$(jp job/train "{.spec.template.spec.volumes[?(@.name==\"$vol\")].persistentVolumeClaim.claimName}")"
why "The image's own copy under /opt/ml-tiny does not count: the dataset must come from the volume."
steps="$(printf '%s\n' "$logs" | sed -n 's/.*done: step \([0-9]*\) .*/\1/p' | tail -n 1)"
check_ge "It trained all 300 steps (done: step ${steps:-?})" 300 "${steps:-0}"
loss="$(final_loss "$logs")"
check "The final loss is below 2.9 (got ${loss:-none})" float_lt "$loss" 2.9
chars=""
if kubectl get pvc dataset >/dev/null 2>&1; then inspect_up dataset; chars="$(mget1 /mnt/dataset/meta.json chars)"; fi
check_ge "The volume holds the prepared dataset (meta.json chars=${chars:-?})" 1000000 "${chars:-0}"
inspect_down
