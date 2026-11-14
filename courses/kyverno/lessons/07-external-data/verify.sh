source "$KDRILL_HOME/courses/kyverno/lib.sh"
P=gpu-access
NOTAPP="is not approved for GPU workloads"
setmax() { kubectl -n platform patch configmap gpu-policy --type=merge -p "{\"data\":{\"max-gpus-per-pod\":\"$1\"}}" >/dev/null 2>&1; }
admitted() { kubectl create --dry-run=server -f "$KYV_PROBE_DIR/$1" -n "$2" >/dev/null 2>&1; }
rejected_with() { local o; o="$(kubectl create --dry-run=server -f "$KYV_PROBE_DIR/$1" -n "$2" 2>&1)" && return 1; [[ "$o" == *"$3"* ]]; }
probe_ns kyv-probe-gpu gpu-access=approved
setmax 4
kyv_settle

check "ClusterPolicy $P exists and is Ready" policy_ready $P
check_eq "Both rules Enforce" "approved-namespace=Enforce max-gpus-per-pod=Enforce" "$(rule_actions $P | tr ' ' '\n' | sort | paste -sd' ' -)"
check "ConfigMap platform/gpu-policy still exists" kubectl -n platform get configmap gpu-policy

echo "approved namespaces (label gpu-access=approved)"
check_admits "ml-team (approved): a 2-GPU Pod is admitted" gpu-2.yaml ml-team
check_rejects "web-team (not approved): the 2-GPU Pod is rejected, naming the namespace" gpu-2.yaml "namespace web-team $NOTAPP" web-team
check_admits "web-team: a Pod without GPUs is admitted" cpu.yaml web-team
check_admits "kyv-probe-gpu, approved just now by label: the 2-GPU Pod is admitted" gpu-2.yaml kyv-probe-gpu
why "Look the namespace up at admission time: context.apiCall.urlPath /api/v1/namespaces/{{ request.namespace }}"
kubectl label ns kyv-probe-gpu gpu-access=revoked --overwrite >/dev/null 2>&1
wait_b 15 rejected_with gpu-2.yaml kyv-probe-gpu "$NOTAPP"
check_rejects "kyv-probe-gpu after relabelling gpu-access=revoked: rejected" gpu-2.yaml "namespace kyv-probe-gpu $NOTAPP" kyv-probe-gpu
kubectl label ns kyv-probe-gpu gpu-access=approved --overwrite >/dev/null 2>&1

echo "GPU maximum from platform/gpu-policy (max-gpus-per-pod)"
check_rejects "max 4: a 6-GPU Pod is rejected with \"at most 4 GPUs per Pod\"" gpu-6.yaml "at most 4 GPUs per Pod" ml-team
setmax 8
wait_b 15 admitted gpu-6.yaml ml-team
check_admits "verify sets max to 8: the 6-GPU Pod is admitted" gpu-6.yaml ml-team
setmax 1
wait_b 15 rejected_with gpu-2.yaml ml-team "at most 1 GPUs per Pod"
check_rejects "verify sets max to 1: the 2-GPU Pod is rejected with \"at most 1 GPUs per Pod\"" gpu-2.yaml "at most 1 GPUs per Pod" ml-team
why "Read the value with a configMap context entry and use {{ name.data.\"max-gpus-per-pod\" }} in the condition and the message."
setmax 4
