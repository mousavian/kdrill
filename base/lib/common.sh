# kdrill script helpers. Sourced automatically before every setup / verify /
# cleanup script, so lesson scripts can use these functions directly.
#
# Environment provided by the engine:
#   KUBECONFIG         dedicated kubeconfig; always points at the kdrill cluster
#   KDRILL_HOME        repo root
#   KDRILL_PHASE       setup | verify | cleanup | install | uninstall
#   KDRILL_LESSON      label value for the active lesson, e.g. k8s-scheduling.01-requests-and-pending
#   KDRILL_LESSON_DIR  directory of the active lesson
#   KDRILL_NS          the lesson's main namespace (also kubectl's default)
#   KDRILL_PROFILE     lite | full

if [[ "${KDRILL_PHASE:-}" != "verify" ]]; then
  set -euo pipefail
fi

LESSON_LABEL_KEY="kdrill.dev/lesson"

info() { printf '  %s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# profile_pick LITE FULL  -> echoes the value for the current profile
profile_pick() {
  if [[ "${KDRILL_PROFILE:-lite}" == "full" ]]; then echo "$2"; else echo "$1"; fi
}

# fake_node NAME [options]
#   Creates a KWOK-managed fake node. Pods scheduled to it go Running without
#   any container actually starting.
#   --cpu N            (default 4)
#   --mem QTY          (default 16Gi)
#   --pods N           (default 110)
#   --gpu N            adds nvidia.com/gpu capacity
#   --resource K=V     any other extended resource (repeatable)
#   --label K=V        (repeatable)
#   --taint K=V:EFFECT (repeatable; "K:EFFECT" for no value)
fake_node() {
  local name="$1"; shift
  local cpu=4 mem=16Gi pods=110
  local -a labels=() taints=() resources=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cpu) cpu="$2"; shift 2 ;;
      --mem) mem="$2"; shift 2 ;;
      --pods) pods="$2"; shift 2 ;;
      --gpu) resources+=("nvidia.com/gpu=$2"); shift 2 ;;
      --resource) resources+=("$2"); shift 2 ;;
      --label) labels+=("$2"); shift 2 ;;
      --taint) taints+=("$2"); shift 2 ;;
      *) die "fake_node: unknown option $1" ;;
    esac
  done

  local label_yaml="" taint_yaml="" res_yaml="" l t r kv key val effect
  for l in ${labels[@]+"${labels[@]}"}; do
    label_yaml+="    ${l%%=*}: \"${l#*=}\""$'\n'
  done
  for r in ${resources[@]+"${resources[@]}"}; do
    res_yaml+="    ${r%%=*}: \"${r#*=}\""$'\n'
  done
  local spec_yaml="spec: {}"
  if [[ ${#taints[@]} -gt 0 ]]; then
    taint_yaml="  taints:"$'\n'
    for t in "${taints[@]}"; do
      effect="${t##*:}"; kv="${t%:*}"; key="${kv%%=*}"; val=""
      [[ "$kv" == *=* ]] && val="${kv#*=}"
      taint_yaml+="  - key: \"$key\""$'\n'
      [[ -n "$val" ]] && taint_yaml+="    value: \"$val\""$'\n'
      taint_yaml+="    effect: $effect"$'\n'
    done
    spec_yaml="spec:"$'\n'"$taint_yaml"
  fi

  kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Node
metadata:
  name: $name
  annotations:
    kwok.x-k8s.io/node: fake
    node.alpha.kubernetes.io/ttl: "0"
  labels:
    kubernetes.io/hostname: $name
    kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    type: kwok
    $LESSON_LABEL_KEY: "${KDRILL_LESSON:-manual}"
$label_yaml
$spec_yaml
status:
  allocatable:
    cpu: "$cpu"
    memory: $mem
    pods: "$pods"
$res_yaml
  capacity:
    cpu: "$cpu"
    memory: $mem
    pods: "$pods"
$res_yaml
YAML
  info "node/$name created (fake: cpu=$cpu mem=$mem${resources[*]:+ ${resources[*]}})"
}

# wait_nodes_ready [TIMEOUT]  - wait until every fake node of this lesson is Ready
wait_nodes_ready() {
  kubectl wait node -l "$LESSON_LABEL_KEY" --for=condition=Ready --timeout="${1:-60s}" >/dev/null
}

# wait_rollout KIND/NAME [TIMEOUT] [NAMESPACE]
wait_rollout() {
  kubectl rollout status "$1" --timeout="${2:-90s}" ${3:+-n "$3"} >/dev/null
}

# wait_until TIMEOUT_SECONDS COMMAND...  - poll until the command succeeds.
# Arguments are expanded once by the caller, so pass a function or command to
# re-run - not a "$(...)" substitution.
wait_until() {
  local timeout="$1"; shift
  local end=$((SECONDS + timeout))
  until "$@" >/dev/null 2>&1; do
    (( SECONDS >= end )) && return 1
    sleep 1
  done
}

# wait_running_count SELECTOR COUNT [TIMEOUT_SECONDS]
#   Poll until exactly COUNT pods matching SELECTOR are Running. Never fails
#   the script: on timeout it just returns, so the learner sees the real state.
wait_running_count() {
  local end=$((SECONDS + ${3:-30}))
  until [[ "$(running_count "$1")" == "$2" ]]; do
    (( SECONDS >= end )) && break
    sleep 1
  done
  return 0
}

# apply_lesson FILE...  - kubectl apply files relative to the lesson directory
apply_lesson() {
  local f
  for f in "$@"; do kubectl apply -f "$KDRILL_LESSON_DIR/$f" >/dev/null; done
}

# ---------------------------------------------------------------- verify ----
# Usage in verify.sh:
#   check "description" COMMAND...          passes when the command exits 0
#   check_eq "description" EXPECTED ACTUAL
#   check_ge "description" MINIMUM ACTUAL   (integers)
#   why "text"                              explanation shown if the previous check failed
# The script's exit status is set automatically: 0 only if every check passed.

_KD_PASS=0; _KD_FAIL=0; _KD_LAST=0

_kd_ok()   { _KD_PASS=$((_KD_PASS+1)); _KD_LAST=0; printf '  \033[32m✓\033[0m %s\n' "$1"; }
_kd_fail() { _KD_FAIL=$((_KD_FAIL+1)); _KD_LAST=1; printf '  \033[31m✗\033[0m %s\n' "$1"; [[ -n "${2:-}" ]] && printf '      %s\n' "$2"; return 0; }

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then _kd_ok "$desc"; else _kd_fail "$desc"; fi
}
check_eq() {
  if [[ "$2" == "$3" ]]; then _kd_ok "$1"; else _kd_fail "$1" "expected: $2   got: ${3:-<nothing>}"; fi
}
check_ge() {
  if [[ "$3" =~ ^[0-9]+$ ]] && (( $3 >= $2 )); then _kd_ok "$1"; else _kd_fail "$1" "expected at least: $2   got: ${3:-<nothing>}"; fi
}
why() { if (( _KD_LAST == 1 )); then printf '      → %s\n' "$*"; fi; return 0; }

# jp RESOURCE JSONPATH [kubectl args...]  - shorthand for a jsonpath query
jp() { local res="$1" path="$2"; shift 2; kubectl get $res -o jsonpath="$path" "$@" 2>/dev/null; }

# cpu_millis QTY -> integer millicores ("2" -> 2000, "500m" -> 500)
cpu_millis() {
  local q="$1"
  if [[ -z "$q" ]]; then echo 0
  elif [[ "$q" == *m ]]; then echo "${q%m}"
  else awk -v q="$q" 'BEGIN{printf "%d", q*1000}'
  fi
}

# pods_on_nodes_with SELECTOR NODE_LABEL_SELECTOR
#   Succeeds when every pod matching SELECTOR (in the lesson namespace) is
#   Running on a node that matches NODE_LABEL_SELECTOR, and there is at least one.
pods_on_nodes_with() {
  local sel="$1" nodesel="$2" nodes pod_nodes n
  nodes=" $(kubectl get nodes -l "$nodesel" -o jsonpath='{.items[*].metadata.name}') "
  pod_nodes="$(kubectl get pods -l "$sel" --field-selector=status.phase=Running -o jsonpath='{.items[*].spec.nodeName}')"
  [[ -n "$pod_nodes" ]] || return 1
  for n in $pod_nodes; do [[ "$nodes" == *" $n "* ]] || return 1; done
}

# running_count SELECTOR -> number of Running pods matching SELECTOR
running_count() {
  kubectl get pods -l "$1" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' '
}

# pods_none_on_nodes_with SELECTOR NODE_LABEL_SELECTOR
#   Succeeds when no pod matching SELECTOR (lesson namespace) is scheduled on a
#   node matching NODE_LABEL_SELECTOR. (Vacuously true if there are no pods.)
pods_none_on_nodes_with() {
  local sel="$1" nodesel="$2" nodes pod_nodes n
  nodes=" $(kubectl get nodes -l "$nodesel" -o jsonpath='{.items[*].metadata.name}') "
  pod_nodes="$(kubectl get pods -l "$sel" -o jsonpath='{.items[*].spec.nodeName}')"
  for n in $pod_nodes; do [[ "$nodes" != *" $n "* ]] || return 1; done
  return 0
}

# hard_node_rule RESOURCE KEY VALUE
#   Succeeds when RESOURCE's pod template (deploy/NAME etc.) has a HARD rule
#   restricting nodes to label KEY=VALUE: either nodeSelector KEY: VALUE, or a
#   requiredDuringSchedulingIgnoredDuringExecution node affinity term with
#   operator In and VALUE among the values for KEY.
hard_node_rule() {
  local res="$1" key="$2" val="$3" esc sel ops vals base
  esc="${key//./\\.}"
  sel="$(jp "$res" "{.spec.template.spec.nodeSelector.$esc}")"
  [[ "$sel" == "$val" ]] && return 0
  base='{.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[*].matchExpressions[?(@.key=="'"$key"'")]'
  ops="$(jp "$res" "$base.operator}")"
  vals="$(jp "$res" "$base.values[*]}")"
  [[ "$ops" == "In" && " $vals " == *" $val "* ]]
}

# pod_distribution SELECTOR NODE_LABEL_KEY
#   Echoes how many live (Running, not terminating) pods matching SELECTOR sit
#   in each value of the node label, as sorted "value:count" words, e.g.
#   "a:2 b:2 c:2". Echoes nothing when there are no such pods.
pod_distribution() {
  local sel="$1" esc="${2//./\\.}" map
  map="$(kubectl get nodes -o jsonpath="{range .items[*]}{.metadata.name} {.metadata.labels.$esc}{\"\\n\"}{end}" 2>/dev/null)"
  kubectl get pods -l "$sel" --no-headers \
      -o custom-columns=NODE:.spec.nodeName,DEL:.metadata.deletionTimestamp,PH:.status.phase 2>/dev/null \
    | KD_MAP="$map" awk 'BEGIN{n=split(ENVIRON["KD_MAP"],l,"\n"); for(i=1;i<=n;i++){split(l[i],f," "); m[f[1]]=f[2]}}
        $3=="Running" && $2=="<none>" {c[m[$1]]++}
        END{for(k in c) print k":"c[k]}' | sort | paste -sd' ' -
}

if [[ "${KDRILL_PHASE:-}" == "verify" ]]; then
  trap '_kd_code=1; (( _KD_FAIL == 0 && _KD_PASS > 0 )) && _kd_code=0; exit $_kd_code' EXIT
fi
