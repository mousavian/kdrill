source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
TSEL='{range .spec.spec.devices.requests[*].exactly.selectors[*]}{.cel.expression}{"\n"}{end}'

# --- llm: memory >= 40Gi
check "ResourceClaimTemplate gpu-40g has a CEL selector on device memory capacity" \
  bash -c '[[ "$1" == *capacity* && "$1" == *memory* ]]' _ "$(jp resourceclaimtemplate/gpu-40g "$TSEL")"
why "selectors: [{cel: {expression: 'device.capacity[\"gpu.nvidia.com\"].memory.compareTo(quantity(\"40Gi\")) >= 0'}}]"
p="$(running_pod app=llm)"; dev="$( [[ -n "$p" ]] && claim_devices "$(pod_claim $p)")"
check "llm is Running with a GPU of at least 40Gi (an L40S or H100, not a 24Gi L4)" \
  bash -c '[[ "$1" =~ ^[a-z0-9-]+/(l40s|h100)-[0-9]+\ $ ]]' _ "$dev"
why "Templates are immutable and claims are made when a pod is created: delete + re-create the template, then kubectl rollout restart deploy llm. (got: ${dev:-nothing})"

# --- trainer: two H100 in one claim
t="$(jp resourceclaimtemplate/two-h100 '{.spec.spec.devices.requests[0].exactly.count}')"
check_eq "ResourceClaimTemplate two-h100 requests count 2" 2 "$t"
check "two-h100 selects by product name or architecture (CEL)" \
  bash -c '[[ "$1" == *productName* || "$1" == *architecture* ]]' _ "$(jp resourceclaimtemplate/two-h100 "$TSEL")"
p="$(running_pod app=trainer)"; dev="$( [[ -n "$p" ]] && claim_devices "$(pod_claim $p)")"
check "trainer is Running with exactly two H100s from one claim" \
  bash -c '[[ "$1" =~ ^h100-1/h100-[0-9]+\ h100-1/h100-[0-9]+\ $ ]]' _ "$dev"
why "got: ${dev:-nothing}"

# --- encoder + decoder share one L4
check_eq "encoder and decoder reference the ResourceClaim shared-l4 (resourceClaimName)" "shared-l4 shared-l4" \
  "$(jp deploy/encoder '{.spec.template.spec.resourceClaims[0].resourceClaimName}') $(jp deploy/decoder '{.spec.template.spec.resourceClaims[0].resourceClaimName}')"
why "A template gives every pod its own claim. To share a device, create one ResourceClaim and use spec.resourceClaims[].resourceClaimName in both."
sdev="$(claim_devices shared-l4)"
check "ResourceClaim shared-l4 is allocated to one L4" bash -c '[[ "$1" =~ ^mixed-1/l4-[0-9]+\ $ ]]' _ "$sdev"
why "got: ${sdev:-nothing}. Select it with device.attributes[\"gpu.nvidia.com\"].productName == \"NVIDIA L4\""
pe="$(running_pod app=encoder)"; pd="$(running_pod app=decoder)"; rf=" $(jp resourceclaim/shared-l4 '{.status.reservedFor[*].name}') "
check "a Running encoder pod and a Running decoder pod both hold shared-l4 (status.reservedFor)" \
  bash -c '[[ -n "$2" && -n "$3" && "$1" == *" $2 "* && "$1" == *" $3 "* ]]' _ "$rf" "$pe" "$pd"

check_eq "One replica each (llm, trainer, encoder, decoder)" "1 1 1 1" \
  "$(jp deploy/llm '{.spec.replicas}') $(jp deploy/trainer '{.spec.replicas}') $(jp deploy/encoder '{.spec.replicas}') $(jp deploy/decoder '{.spec.replicas}')"
check_eq "Still 2 nodes" 2 "$(fake_node_count)"
check_fleet_unchanged kubectl get deviceclass gpu.nvidia.com -o jsonpath='{.spec}'
