source "$KDRILL_HOME/courses/kyverno/lib.sh"
P=pod-security-baseline
HP="hostPath volumes are not allowed"
probe_ns kyv-probe-other
kyv_settle

check "ClusterPolicy $P exists and is Ready" policy_ready $P
check_eq "The policy itself is unchanged (both rules Enforce, no exclude)" "disallow-host-path=Enforce disallow-privileged=Enforce|" \
  "$(rule_actions $P | tr ' ' '\n' | sort | paste -sd' ' -)|$(jp clusterpolicy/$P '{.spec.rules[*].exclude}')"
why "Exempt the workload with a PolicyException; don't weaken the policy for everyone. kdrill reset restores it."
n="$(kubectl -n policy-exceptions get policyexceptions.kyverno.io -o name 2>/dev/null | wc -l | tr -d ' ')"
check_ge "A PolicyException exists in namespace policy-exceptions" 1 "$n"
why "This cluster only honours exceptions in policy-exceptions (Kyverno flag --exceptionNamespace). The one in gpu-operator is ignored."

echo "the exporter"
check_eq "DaemonSet gpu-operator/dcgm-exporter exists" dcgm-exporter "$(jp daemonset/dcgm-exporter '{.metadata.name}' -n gpu-operator)"
why "kubectl apply -f manifests/dcgm-exporter.yaml (after the exception exists)"
ds="$(jp daemonset/dcgm-exporter '{.status.desiredNumberScheduled} {.status.numberReady}' -n gpu-operator)"
check "dcgm-exporter: a ready Pod on every worker node" bash -c 'set -- $1; [[ -n "$1" && "$1" -ge 2 && "$1" == "$2" ]]' _ "$ds"
why "kubectl -n gpu-operator describe ds dcgm-exporter (FailedCreate events mean the Pods are still rejected)"
check_eq "dcgm-exporter still mounts the hostPath, and is not privileged" "/var/lib/kubelet/pod-resources|" \
  "$(jp daemonset/dcgm-exporter '{.spec.template.spec.volumes[*].hostPath.path}|{.spec.template.spec.containers[*].securityContext.privileged}' -n gpu-operator)"

echo "the exception is narrow (dry-run of probes/)"
check_admits "gpu-operator: a dcgm-exporter-* Pod with the hostPath is admitted" exporter-pod.yaml gpu-operator
check_rejects "gpu-operator: a dcgm-exporter-* Pod that is privileged is still rejected" exporter-pod-privileged.yaml "privileged containers are not allowed" gpu-operator
why "Only exempt the rule you need (ruleNames)."
check_rejects "gpu-operator: another Pod (node-debugger) with a hostPath is still rejected" other-pod.yaml "$HP" gpu-operator
why "Match the exporter by name, not the whole namespace."
check_rejects "another namespace: the dcgm-exporter-* Pod is still rejected" exporter-pod.yaml "$HP" kyv-probe-other
