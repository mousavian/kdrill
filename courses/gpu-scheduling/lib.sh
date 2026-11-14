# Helpers for the gpu-scheduling course. Lesson scripts source this file:
#   source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
# common.sh (fake_node, check, jp, ...) is already loaded at that point.
# Written for bash 3.2: no associative arrays, no mapfile.

# _gpu_model MODEL -> "product|memMiB|family|ccMajor|ccMinor|draProduct|draArch|draMemGi|instPrefix"
_gpu_model() {
  case "$1" in
    t4)   echo "Tesla-T4|15360|turing|7|5|Tesla T4|Turing|16|g4dn" ;;
    a10g) echo "NVIDIA-A10G|23028|ampere|8|6|NVIDIA A10G|Ampere|24|g5" ;;
    l4)   echo "NVIDIA-L4|23034|ada-lovelace|8|9|NVIDIA L4|Ada Lovelace|24|g6" ;;
    l40s) echo "NVIDIA-L40S|46068|ada-lovelace|8|9|NVIDIA L40S|Ada Lovelace|48|g6e" ;;
    a100) echo "NVIDIA-A100-SXM4-80GB|81920|ampere|8|0|NVIDIA A100-SXM4-80GB|Ampere|80|p4de" ;;
    h100) echo "NVIDIA-H100-80GB-HBM3|81559|hopper|9|0|NVIDIA H100 80GB HBM3|Hopper|80|p5" ;;
    *) die "unknown GPU model $1 (t4 a10g l4 l40s a100 h100)" ;;
  esac
}

_instance_type() {  # _instance_type PREFIX COUNT
  case "$1:$2" in
    p4de:*) echo p4de.24xlarge ;;
    p5:*)   echo p5.48xlarge ;;
    *:1)    echo "$1.xlarge" ;;
    *:4)    echo "$1.12xlarge" ;;
    *:8)    echo "$1.48xlarge" ;;
    *)      echo "$1.${2}gpu" ;;
  esac
}

# gpu_node NAME MODEL COUNT [options] [fake_node options...]
#   A fake GPU node labelled the way NVIDIA GPU Feature Discovery (GFD), Node
#   Feature Discovery (NFD) and the device plugin would label it.
#   --shared N         time-slicing: advertise COUNT*N nvidia.com/gpu replicas
#   --mig P=N          MIG "mixed" strategy: advertise nvidia.com/mig-P (repeatable);
#                      all GPUs are partitioned, so no nvidia.com/gpu is advertised
#   --mig-config NAME  value for nvidia.com/mig.config (default: custom)
#   --dra              no extended resource at all (GPUs are published as DRA
#                      ResourceSlices instead, see dra_slice)
#   Any other option is passed to fake_node (later options win, e.g. --cpu).
gpu_node() {
  local name="$1" model="$2" count="$3"; shift 3
  local spec product mem family ccmaj ccmin x1 x2 x3 inst
  spec="$(_gpu_model "$model")"
  IFS='|' read -r product mem family ccmaj ccmin x1 x2 x3 inst <<<"$spec"
  local shared="" dra="" migcfg="custom"
  local -a migs=() pass=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --shared) shared="$2"; shift 2 ;;
      --mig) migs+=("$2"); shift 2 ;;
      --mig-config) migcfg="$2"; shift 2 ;;
      --dra) dra=1; shift ;;
      *) pass+=("$1"); shift ;;
    esac
  done
  local cpu=$((count * 12)) memgi=$((count * 64))
  (( cpu < 8 )) && cpu=8
  local -a args=(--cpu "$cpu" --mem "${memgi}Gi"
    --label "node.kubernetes.io/instance-type=$(_instance_type "$inst" "$count")"
    --label "feature.node.kubernetes.io/pci-10de.present=true"
    --label "nvidia.com/gpu.present=true"
    --label "nvidia.com/gpu.count=$count"
    --label "nvidia.com/gpu.memory=$mem"
    --label "nvidia.com/gpu.family=$family"
    --label "nvidia.com/gpu.compute.major=$ccmaj"
    --label "nvidia.com/gpu.compute.minor=$ccmin"
    --label "nvidia.com/cuda.driver.major=580")
  if [[ "$model" == a100 || "$model" == h100 ]]; then
    args+=(--label "nvidia.com/mig.capable=true")
  fi
  if [[ -n "$shared" ]]; then
    args+=(--label "nvidia.com/gpu.product=${product}-SHARED"
           --label "nvidia.com/gpu.replicas=$shared"
           --label "nvidia.com/gpu.sharing-strategy=time-slicing"
           --gpu $((count * shared)))
  else
    args+=(--label "nvidia.com/gpu.product=$product"
           --label "nvidia.com/gpu.replicas=1"
           --label "nvidia.com/gpu.sharing-strategy=none")
  fi
  if [[ ${#migs[@]} -gt 0 ]]; then
    local m p n
    args+=(--label "nvidia.com/mig.strategy=mixed" --label "nvidia.com/mig.config=$migcfg"
           --label "nvidia.com/mig.config.state=success")
    for m in "${migs[@]}"; do
      p="${m%%=*}"; n="${m#*=}"
      args+=(--resource "nvidia.com/mig-$p=$n" --label "nvidia.com/mig-$p.count=$n")
    done
  elif [[ -z "$shared" && -z "$dra" ]]; then
    args+=(--gpu "$count")
  fi
  fake_node "$name" "${args[@]}" ${pass[@]+"${pass[@]}"}
}

# dra_slice NODE MODEL COUNT [MODEL COUNT]...
#   Publishes a ResourceSlice for NODE under driver gpu.nvidia.com, with
#   attributes modelled on the NVIDIA DRA driver. Device names are
#   <model>-<index>, e.g. h100-0. (On a real cluster the driver's kubelet
#   plugin publishes this; KWOK nodes have no kubelet, so we write it.)
dra_slice() {
  local node="$1"; shift
  local devs="" idx=0 model count i spec product mem family ccmaj ccmin dprod darch dmem inst
  while [[ $# -gt 0 ]]; do
    model="$1"; count="$2"; shift 2
    spec="$(_gpu_model "$model")"
    IFS='|' read -r product mem family ccmaj ccmin dprod darch dmem inst <<<"$spec"
    i=0
    while (( i < count )); do
      devs+="  - name: ${model}-${i}
    attributes:
      type: {string: gpu}
      uuid: {string: \"GPU-$(printf '%08x' $(( $(printf '%s' "$node" | cksum | cut -d' ' -f1) % 4294967295 )))-$(printf '%04d' $idx)\"}
      productName: {string: \"${dprod}\"}
      brand: {string: Nvidia}
      architecture: {string: \"${darch}\"}
      cudaComputeCapability: {version: \"${ccmaj}.${ccmin}.0\"}
      driverVersion: {version: \"580.82.7\"}
    capacity:
      memory: {value: ${dmem}Gi}
"
      i=$((i + 1)); idx=$((idx + 1))
    done
  done
  kubectl apply -f - >/dev/null <<YAML
apiVersion: resource.k8s.io/v1
kind: ResourceSlice
metadata:
  name: ${node}-gpu.nvidia.com
  labels:
    $LESSON_LABEL_KEY: "${KDRILL_LESSON:-manual}"
spec:
  driver: gpu.nvidia.com
  nodeName: ${node}
  pool:
    name: ${node}
    generation: 1
    resourceSliceCount: 1
  devices:
$devs
YAML
  info "resourceslice/${node}-gpu.nvidia.com published ($idx GPUs)"
}

# gpu_device_class  - the DeviceClass the NVIDIA DRA driver would install.
gpu_device_class() {
  kubectl apply -f - >/dev/null <<YAML
apiVersion: resource.k8s.io/v1
kind: DeviceClass
metadata:
  name: gpu.nvidia.com
  labels:
    $LESSON_LABEL_KEY: "${KDRILL_LESSON:-manual}"
spec:
  selectors:
  - cel:
      expression: device.driver == "gpu.nvidia.com" && device.attributes["gpu.nvidia.com"].type == "gpu"
YAML
}

# ------------------------------------------------------------ baselines ----
# Setup records what the fleet looks like; verify compares, so editing nodes,
# ResourceSlices etc. is caught. Stored in a ConfigMap in the lesson namespace.

_fleet_state() {
  kubectl get nodes -l "$LESSON_LABEL_KEY" -o jsonpath='{range .items[*]}{.metadata.name}|{.metadata.labels}|{.spec.taints}|{.spec.unschedulable}|{.status.allocatable}{"\n"}{end}' 2>/dev/null | sort
  kubectl get resourceslices -l "$LESSON_LABEL_KEY" -o jsonpath='{range .items[*]}{.metadata.name}|{.spec}{"\n"}{end}' 2>/dev/null | sort
}

# baseline_save [EXTRA_COMMAND...] - record the fleet (+ the output of an
# optional command, e.g. quotas) right after setup.
baseline_save() {
  local extra=""
  if [[ $# -gt 0 ]]; then extra="$("$@" 2>/dev/null)"; fi
  kubectl -n "$KDRILL_NS" create configmap kdrill-baseline \
    --from-literal=fleet="$(_fleet_state)" --from-literal=extra="$extra" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

# check_fleet_unchanged [EXTRA_COMMAND...] - verify-side counterpart.
check_fleet_unchanged() {
  local want got
  want="$(kubectl -n "$KDRILL_NS" get configmap kdrill-baseline -o jsonpath='{.data.fleet}' 2>/dev/null)"
  got="$(_fleet_state)"
  if [[ -n "$want" && "$want" == "$got" ]]; then _kd_ok "GPU nodes (labels, taints, capacity) and ResourceSlices are unchanged"
  else _kd_fail "GPU nodes (labels, taints, capacity) and ResourceSlices are unchanged"; fi
  why "Change the workloads, not the fleet. (Deleted configmap kdrill-baseline? Run kdrill reset.)"
  if [[ $# -gt 0 ]]; then
    want="$(kubectl -n "$KDRILL_NS" get configmap kdrill-baseline -o jsonpath='{.data.extra}' 2>/dev/null)"
    got="$("$@" 2>/dev/null)"
    if [[ -n "$want" && "$want" == "$got" ]]; then return 0; fi
    _kd_fail "Pre-existing configuration is unchanged" "expected: $(echo $want)   got: $(echo $got)"
  fi
}

# ------------------------------------------------------------ verify helpers ----

# live_count PHASE SELECTOR [NAMESPACE] -> non-terminating pods in PHASE
live_count() {
  kubectl get pods -l "$2" ${3:+-n "$3"} --no-headers \
      -o custom-columns=DEL:.metadata.deletionTimestamp,PH:.status.phase 2>/dev/null \
    | awk -v ph="$1" '$1=="<none>" && $2==ph' | wc -l | tr -d ' '
}

# fake_node_count -> number of fake nodes of this lesson
fake_node_count() { kubectl get nodes -l "$LESSON_LABEL_KEY" --no-headers 2>/dev/null | wc -l | tr -d ' '; }

# res_limit RESOURCE KIND/NAME [NAMESPACE] -> the first container's limit for RESOURCE
res_limit() {
  local esc="${1//./\\.}"
  jp "$2" "{.spec.template.spec.containers[0].resources.limits.$esc}" ${3:+-n "$3"}
}

# res_keys KIND/NAME [NAMESPACE] -> all resource names requested/limited by the pod template
res_keys() {
  kubectl get "$1" ${2:+-n "$2"} -o jsonpath='{range .spec.template.spec.containers[*]}{.resources.limits}{" "}{.resources.requests}{"\n"}{end}' 2>/dev/null
}

# no_gpu_overcommit RESOURCE - no node has more RESOURCE requested by live pods
# than it can allocate. (KWOK has no kubelet admission, so two schedulers
# racing could overbook a fake node; a real kubelet would reject the pod.)
no_gpu_overcommit() {
  local esc="${1//./\\.}" alloc used
  alloc="$(kubectl get nodes -l "$LESSON_LABEL_KEY" -o jsonpath="{range .items[*]}{.metadata.name} {.status.allocatable.$esc}{\"\\n\"}{end}")"
  used="$(kubectl get pods -A --field-selector=status.phase!=Succeeded,status.phase!=Failed -o jsonpath="{range .items[*]}{.spec.nodeName} {range .spec.containers[*]}{.resources.requests.$esc}{\" \"}{end}{\"\\n\"}{end}")"
  KD_ALLOC="$alloc" awk 'BEGIN{n=split(ENVIRON["KD_ALLOC"],l,"\n"); for(i=1;i<=n;i++){split(l[i],f," "); if(f[1]!="") a[f[1]]=f[2]+0}}
      NF>1 {for(i=2;i<=NF;i++) u[$1]+=$i}
      END{bad=0; for(k in u) if((k in a) && u[k]>a[k]) bad=1; exit bad}' <<<"$used"
}

# required_affinity_keys KIND/NAME -> keys used in nodeSelector and in required node affinity
required_affinity_keys() {
  local r="$1"
  { kubectl get "$r" -o jsonpath='{.spec.template.spec.nodeSelector}' 2>/dev/null | tr ',{}' '\n\n\n' | sed -n 's/^"\([^"]*\)":.*/\1/p'
    jp "$r" '{.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[*].matchExpressions[*].key}' | tr ' ' '\n'
  } | sort -u | paste -sd' ' -
}

# --- Kueue -------------------------------------------------------------------

# wl_state NAMESPACE JOB -> admitted | pending | finished | none
#   State of the Kueue Workload owned by Job JOB.
wl_state() {
  local ns="$1" job="$2" line
  line="$(kubectl -n "$ns" get workloads -o jsonpath='{range .items[*]}{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name} {.status.conditions[?(@.type=="Admitted")].status} {.status.conditions[?(@.type=="Finished")].status}{"\n"}{end}' 2>/dev/null | awk -v j="Job/$job" '$1==j')"
  if [[ -z "$line" ]]; then echo none; return; fi
  set -- $line
  if [[ "${3:-}" == True ]]; then echo finished
  elif [[ "${2:-}" == True ]]; then echo admitted
  else echo pending; fi
}

# job_running JOB [NAMESPACE] -> Running, non-terminating pods of the Job
job_running() { live_count Running "batch.kubernetes.io/job-name=$1" "${2:-}"; }

# job_pods JOB [NAMESPACE] -> all non-terminating pods of the Job (any phase)
job_pods() {
  kubectl get pods -l "batch.kubernetes.io/job-name=$1" ${2:+-n "$2"} --no-headers \
      -o custom-columns=DEL:.metadata.deletionTimestamp 2>/dev/null | awk '$1=="<none>"' | wc -l | tr -d ' '
}

# kueue_cleanup [CLUSTERQUEUE...] [-- RESOURCEFLAVOR...]
#   Delete learner-created Kueue objects. Jobs go first so the ClusterQueue
#   finalizer (which waits for admitted workloads) does not block.
kueue_cleanup() {
  local ns cqs="" rfs="" mode=cq a
  for a in "$@"; do
    if [[ "$a" == "--" ]]; then mode=rf; continue; fi
    if [[ "$mode" == cq ]]; then cqs+=" $a"; else rfs+=" $a"; fi
  done
  for ns in $(kubectl get ns -l "$LESSON_LABEL_KEY" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    kubectl -n "$ns" delete jobs --all --cascade=background --ignore-not-found --wait=false >/dev/null 2>&1 || true
    kubectl -n "$ns" delete workloads.kueue.x-k8s.io --all --ignore-not-found --timeout=30s >/dev/null 2>&1 || true
    kubectl -n "$ns" delete localqueues.kueue.x-k8s.io --all --ignore-not-found --timeout=30s >/dev/null 2>&1 || true
  done
  # shellcheck disable=SC2086
  [[ -n "$cqs" ]] && kubectl delete clusterqueues.kueue.x-k8s.io $cqs --ignore-not-found --timeout=60s >/dev/null 2>&1
  # shellcheck disable=SC2086
  [[ -n "$rfs" ]] && kubectl delete resourceflavors.kueue.x-k8s.io $rfs --ignore-not-found --timeout=60s >/dev/null 2>&1
  return 0
}

# quotas -> one line per ClusterQueue: "<cq> <flavor> gpu=<nominalQuota>/<lendingLimit>"
#   (GPU resources only; used for baselines)
quotas() {
  kubectl get clusterqueues.kueue.x-k8s.io -o jsonpath='{range .items[*]}{.metadata.name}{range .spec.resourceGroups[*].flavors[*]} {.name}{range .resources[?(@.name=="nvidia.com/gpu")]} gpu={.nominalQuota}/{.lendingLimit}{end}{end}{"\n"}{end}' 2>/dev/null
}

# --- DRA -----------------------------------------------------------------------

# pod_claim POD -> name of the ResourceClaim behind the pod's first claim
#   (generated from a template, or referenced directly by resourceClaimName)
pod_claim() {
  local c
  c="$(jp "pod/$1" '{.spec.resourceClaims[0].resourceClaimName}')"
  [[ -n "$c" ]] || c="$(jp "pod/$1" '{.status.resourceClaimStatuses[0].resourceClaimName}')"
  echo "$c"
}

# claim_devices CLAIM -> allocated devices as "pool/device" words
claim_devices() { jp "resourceclaim/$1" '{range .status.allocation.devices.results[*]}{.pool}/{.device} {end}'; }

# running_pod SELECTOR -> name of one Running, non-terminating pod
running_pod() {
  kubectl get pods -l "$1" --field-selector=status.phase=Running --no-headers \
      -o custom-columns=N:.metadata.name,DEL:.metadata.deletionTimestamp 2>/dev/null | awk '$2=="<none>"{print $1; exit}'
}

# wait_running TIMEOUT N SELECTOR [NAMESPACE]
#   Wait until exactly N live pods matching SELECTOR are Running. (Passing
#   "$(running_count ...)" to wait_until would only evaluate it once.)
wait_running() { wait_until "$1" _running_is "$2" "$3" "${4:-}"; }
_running_is() { [[ "$(live_count Running "$2" "$3")" == "$1" ]]; }

# capstone_config -> the queue/quota/DeviceClass setup of the capstone (for baselines)
capstone_config() {
  quotas
  kubectl get localqueues.kueue.x-k8s.io -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}->{.spec.clusterQueue} {end}'; echo
  kubectl get resourceflavors.kueue.x-k8s.io -o jsonpath='{range .items[*]}{.metadata.name}:{.spec.nodeLabels} {end}'; echo
  kubectl get resourcequota -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}:{.spec.hard} {end}'; echo
  kubectl get deviceclass -o jsonpath='{range .items[*]}{.metadata.name}:{.spec} {end}'; echo
}

# pods_on_nodes_with_ns NAMESPACE SELECTOR NODE_LABEL_SELECTOR - pods_on_nodes_with for another namespace
pods_on_nodes_with_ns() {
  local ns="$1" sel="$2" nodesel="$3" nodes pod_nodes n
  nodes=" $(kubectl get nodes -l "$nodesel" -o jsonpath='{.items[*].metadata.name}') "
  pod_nodes="$(kubectl -n "$ns" get pods -l "$sel" --field-selector=status.phase=Running -o jsonpath='{.items[*].spec.nodeName}')"
  [[ -n "$pod_nodes" ]] || return 1
  for n in $pod_nodes; do [[ "$nodes" == *" $n "* ]] || return 1; done
}
