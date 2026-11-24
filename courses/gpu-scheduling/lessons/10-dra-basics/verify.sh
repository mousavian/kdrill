source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"

sel="$(jp deviceclass/gpu.nvidia.com '{.spec.selectors[*].cel.expression}')"
check "DeviceClass gpu.nvidia.com selects devices of driver gpu.nvidia.com (CEL on device.driver)" \
  bash -c '[[ "$1" == *device.driver* && "$1" == *gpu.nvidia.com* ]]' _ "$sel"
why "spec.selectors: [{cel: {expression: 'device.driver == \"gpu.nvidia.com\"'}}]"
reqs="$(jp resourceclaimtemplate/one-gpu '{range .spec.spec.devices.requests[*]}{.exactly.deviceClassName}/{.exactly.allocationMode}/{.exactly.count};{end}')"
check "ResourceClaimTemplate one-gpu requests exactly one device of class gpu.nvidia.com" \
  bash -c '[[ "$1" =~ ^gpu\.nvidia\.com/(ExactCount)?/(1)?\;$ ]]' _ "$reqs"
why "spec.spec.devices.requests: [{name: gpu, exactly: {deviceClassName: gpu.nvidia.com}}] (count defaults to 1)"

check_eq "vllm: 3 replicas, all ready" 3 "$(jp deploy/vllm '{.status.readyReplicas}')"
why "kubectl describe pod -l app=vllm: look for events about the ResourceClaimTemplate / DeviceClass."
check_eq "vllm pods use resourceClaimTemplateName one-gpu and no nvidia.com/gpu" "one-gpu" \
  "$(jp deploy/vllm '{.spec.template.spec.resourceClaims[*].resourceClaimTemplateName}')$(res_keys deploy/vllm | grep -o 'nvidia.com/gpu' | head -1)"
check_eq "vllm still has spec.replicas 3" 3 "$(jp deploy/vllm '{.spec.replicas}')"

bad=""; seen=""; dup=""; n=0
for pod in $(kubectl get pods -l app=vllm --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
  node="$(jp pod/$pod '{.spec.nodeName}')"
  claim="$(jp pod/$pod '{.status.resourceClaimStatuses[0].resourceClaimName}')"
  res="$(jp resourceclaim/$claim '{range .status.allocation.devices.results[*]}{.driver}/{.pool}/{.device} {end}')"
  owner="$(jp resourceclaim/$claim '{.status.reservedFor[*].name}')"
  set -- $res
  if [[ $# -ne 1 || "$1" != gpu.nvidia.com/$node/* || " $owner " != *" $pod "* ]]; then bad+="$pod "; fi
  if [[ -n "${1:-}" ]]; then
    [[ " $seen " == *" $1 "* ]] && dup+="$1 "
    seen+=" $1"
  fi
  n=$((n+1))
done
check "every running vllm pod has its own allocated ResourceClaim: 1 GPU from its own node's pool" bash -c '[[ "$1" -gt 0 && -z "$2" ]]' _ "$n" "$bad"
why "kubectl get resourceclaims; kubectl get resourceclaim <name> -o yaml (status.allocation, status.reservedFor)"
check_eq "no GPU is allocated twice" "" "$dup"
check_eq "Still 2 nodes" 2 "$(fake_node_count)"
check_fleet_unchanged
