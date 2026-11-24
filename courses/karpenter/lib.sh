# Helpers for the karpenter course. Lesson scripts source this file:
#   source "$KDRILL_HOME/courses/karpenter/lib.sh"
# common.sh (check, check_eq, jp, ...) is already loaded at that point.
# Written for bash 3.2: no associative arrays, no mapfile.
#
# Karpenter runs in namespace "karpenter" (component karpenter-kwok). The
# nodes it launches are KWOK fake nodes: label karpenter.sh/nodepool, provider
# ID kwok://..., one NodeClaim each.

KARP_NS=karpenter

# ------------------------------------------------------------------ setup ----

# karp_apply FILE...  - kubectl apply lesson files (relative to the lesson
# directory) and label every object in them for this lesson, so the engine's
# cleanup removes the cluster-scoped ones (NodePools, KWOKNodeClasses).
karp_apply() {
  local f
  for f in "$@"; do
    kubectl apply -f "$KDRILL_LESSON_DIR/$f" >/dev/null
    kubectl label --overwrite -f "$KDRILL_LESSON_DIR/$f" "$LESSON_LABEL_KEY=$KDRILL_LESSON" >/dev/null
  done
}

# karp_nodeclass [NAME]  - the KWOKNodeClass most NodePools point to (default: "default").
karp_nodeclass() {
  kubectl apply -f - >/dev/null <<YAML
apiVersion: karpenter.kwok.sh/v1alpha1
kind: KWOKNodeClass
metadata:
  name: ${1:-default}
  labels:
    $LESSON_LABEL_KEY: "$KDRILL_LESSON"
YAML
}

# karp_require  - fail early with a clear message if Karpenter isn't running.
karp_require() {
  kubectl -n "$KARP_NS" rollout status deploy/karpenter --timeout=60s >/dev/null 2>&1 ||
    die "Karpenter is not running (kubectl -n $KARP_NS get pods). Try: kdrill course stop karpenter && kdrill course start karpenter"
}

# karp_wait_running NS SELECTOR COUNT [TIMEOUT_SECONDS]
#   Wait until COUNT live pods are Running. Never fails: on timeout the learner
#   just sees the real state.
karp_wait_running() {
  local end=$((SECONDS + ${4:-60}))
  until [[ "$(live_running "$1" "$2")" == "$3" ]]; do
    (( SECONDS >= end )) && break
    sleep 1
  done
  return 0
}

# karp_wait_settled [TIMEOUT_SECONDS]  - wait until no NodeClaim or Karpenter
# node is being deleted or still launching (best effort).
karp_wait_settled() {
  local end=$((SECONDS + ${1:-60}))
  until _karp_settled; do
    (( SECONDS >= end )) && break
    sleep 2
  done
  return 0
}
_karp_settled() {
  local busy
  busy="$(kubectl get nodeclaims -o jsonpath='{range .items[*]}{.metadata.deletionTimestamp}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -cv '^True$')"
  [[ "$busy" == 0 ]]
}

# baseline_save [KEY=COMMAND]...  - record the lesson start time (for event
# checks) plus the output of each COMMAND (for "unchanged" guard checks).
# Stored in ConfigMap kdrill-baseline in the lesson namespace.
baseline_save() {
  local -a args=(--from-literal=start="$(date -u +%Y-%m-%dT%H:%M:%SZ)")
  local kv
  for kv in "$@"; do
    args+=(--from-literal="${kv%%=*}=$(eval "${kv#*=}" 2>/dev/null)")
  done
  kubectl -n "$KDRILL_NS" create configmap kdrill-baseline "${args[@]}" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

baseline_get() { kubectl -n "$KDRILL_NS" get configmap kdrill-baseline -o jsonpath="{.data.$1}" 2>/dev/null; }

# ---------------------------------------------------------------- cleanup ----

# karp_cleanup  - remove everything Karpenter launched for the lesson, reliably:
#   1. delete the lesson namespaces first, so no PodDisruptionBudget or
#      do-not-disrupt pod can block draining (and nothing is left Pending)
#   2. delete every NodePool (setup's and the learner's) and NodeClaim; the
#      controller drains and removes the fake nodes (finalizer karpenter.sh/termination)
#   3. after 60 s, strip finalizers from whatever is left so cleanup never hangs
#   4. delete the KWOKNodeClasses
# This course owns Karpenter on the cluster, so "every NodePool" is safe here.
karp_cleanup() {
  kubectl delete ns -l "$LESSON_LABEL_KEY" --ignore-not-found --timeout=90s >/dev/null 2>&1 || {
    local ns
    for ns in $(kubectl get ns -l "$LESSON_LABEL_KEY" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
      kubectl -n "$ns" delete pods --all --force --grace-period=0 --wait=false >/dev/null 2>&1 || true
    done
  }
  kubectl delete nodepools.karpenter.sh --all --wait=false >/dev/null 2>&1 || true
  kubectl delete nodeclaims.karpenter.sh --all --wait=false >/dev/null 2>&1 || true
  wait_until 60 _karp_gone || true
  local o
  for o in $(kubectl get nodeclaims.karpenter.sh -o name 2>/dev/null); do
    kubectl patch "$o" --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
  done
  for o in $(_karp_all_nodes); do
    kubectl patch "node/$o" --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
    kubectl delete "node/$o" --wait=false >/dev/null 2>&1 || true
  done
  kubectl delete kwoknodeclasses.karpenter.kwok.sh --all --wait=false >/dev/null 2>&1 || true
  wait_until 30 _karp_gone || true
  return 0
}
# every node that isn't a real k3d node: Karpenter's and any hand-made fake node
_karp_all_nodes() {
  kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}' 2>/dev/null
}
_karp_gone() {
  [[ -z "$(kubectl get nodeclaims.karpenter.sh -o name 2>/dev/null)" && -z "$(_karp_all_nodes)" ]]
}

# ------------------------------------------------------------ observations ----

# live_running NS SELECTOR -> number of Running, non-terminating pods
live_running() {
  kubectl -n "$1" get pods -l "$2" --no-headers \
      -o custom-columns=DEL:.metadata.deletionTimestamp,PH:.status.phase 2>/dev/null \
    | awk '$1=="<none>" && $2=="Running"' | wc -l | tr -d ' '
}

# live_pending NS SELECTOR -> number of Pending, non-terminating pods
live_pending() {
  kubectl -n "$1" get pods -l "$2" --no-headers \
      -o custom-columns=DEL:.metadata.deletionTimestamp,PH:.status.phase 2>/dev/null \
    | awk '$1=="<none>" && $2=="Pending"' | wc -l | tr -d ' '
}

# running_pod SELECTOR [NS] -> name of one Running, non-terminating pod
running_pod() {
  kubectl get pods -l "$1" ${2:+-n "$2"} --field-selector=status.phase=Running --no-headers \
      -o custom-columns=N:.metadata.name,DEL:.metadata.deletionTimestamp 2>/dev/null | awk '$2=="<none>"{print $1; exit}'
}

# _node_table KEY... -> "name deleting value1 value2 ..." per node ("-" = unset)
_node_table() {
  local fmt='{range .items[*]}{.metadata.name}{" "}{.metadata.deletionTimestamp}{"|"}' k esc
  for k in "$@"; do esc="${k//./\\.}"; fmt+="{.metadata.labels.$esc}{\"|\"}"; done
  fmt+='{"\n"}{end}'
  kubectl get nodes -o jsonpath="$fmt" 2>/dev/null \
    | awk -F'|' '{ split($1, a, " "); d = (a[2] == "" ? "live" : "deleting"); line = a[1] " " d;
                   for (i = 2; i < NF; i++) line = line " " ($i == "" ? "-" : $i); print line }'
}

# pod_node_labels NS SELECTOR KEY -> sorted, unique values of node label KEY
#   for the nodes running the live Running pods (e.g. "c6i.xlarge m6i.large")
pod_node_labels() {
  local map
  map="$(_node_table "$3")"
  kubectl -n "$1" get pods -l "$2" --no-headers \
      -o custom-columns=NODE:.spec.nodeName,DEL:.metadata.deletionTimestamp,PH:.status.phase 2>/dev/null \
    | KD_MAP="$map" awk 'BEGIN{n=split(ENVIRON["KD_MAP"],l,"\n"); for(i=1;i<=n;i++){split(l[i],f," "); m[f[1]]=f[3]}}
        $3=="Running" && $2=="<none>" {print (($1 in m) ? m[$1] : "-")}' | sort -u | paste -sd' ' -
}

# pod_spread NS SELECTOR KEY -> "value:count" words: live Running pods per value
#   of node label KEY, e.g. "us-west-2a:2 us-west-2b:2 us-west-2c:2"
pod_spread() {
  local map
  map="$(_node_table "$3")"
  kubectl -n "$1" get pods -l "$2" --no-headers \
      -o custom-columns=NODE:.spec.nodeName,DEL:.metadata.deletionTimestamp,PH:.status.phase 2>/dev/null \
    | KD_MAP="$map" awk 'BEGIN{n=split(ENVIRON["KD_MAP"],l,"\n"); for(i=1;i<=n;i++){split(l[i],f," "); m[f[1]]=f[3]}}
        $3=="Running" && $2=="<none>" {c[(($1 in m) ? m[$1] : "-")]++}
        END{for(k in c) print k":"c[k]}' | sort | paste -sd' ' -
}

# karp_nodes [LABEL_SELECTOR] -> names of live (not deleting) Karpenter nodes
karp_nodes() {
  kubectl get nodes -l "karpenter.sh/nodepool${1:+,$1}" --no-headers \
      -o custom-columns=N:.metadata.name,DEL:.metadata.deletionTimestamp 2>/dev/null | awk '$2=="<none>"{print $1}'
}

# karp_node_count [LABEL_SELECTOR] -> number of live Karpenter nodes
karp_node_count() { karp_nodes "${1:-}" | wc -l | tr -d ' '; }

# karp_node_labels KEY [LABEL_SELECTOR] -> sorted unique values of KEY on live Karpenter nodes
karp_node_labels() {
  local esc="${1//./\\.}"
  kubectl get nodes -l "karpenter.sh/nodepool${2:+,$2}" --no-headers \
      -o custom-columns=V:.metadata.labels.$esc,DEL:.metadata.deletionTimestamp 2>/dev/null \
    | awk '$2=="<none>"{print $1}' | sort -u | paste -sd' ' -
}

# karp_capacity RESOURCE [LABEL_SELECTOR] -> sum of RESOURCE capacity over live
#   Karpenter nodes (cpu in cores, memory in Gi, others as integers)
karp_capacity() {
  local esc="${1//./\\.}"
  kubectl get nodes -l "karpenter.sh/nodepool${2:+,$2}" --no-headers \
      -o custom-columns=V:.status.capacity.$esc,DEL:.metadata.deletionTimestamp 2>/dev/null \
    | awk -v r="$1" '$2=="<none>" && $1!="<none>" {
        v=$1
        if (r=="memory") { if (v ~ /Gi$/) v=v+0; else if (v ~ /Mi$/) v=v/1024; else if (v ~ /Ki$/) v=v/1048576; else v=v/1073741824 }
        else if (v ~ /m$/) v=v/1000
        s+=v } END{printf "%g\n", s+0}'
}

# idle_gpus -> GPUs on live Karpenter nodes not requested by any live pod
idle_gpus() {
  local alloc used
  alloc="$(kubectl get nodes -l karpenter.sh/nodepool -o jsonpath='{range .items[*]}{.metadata.name} {.metadata.deletionTimestamp}{"|"}{.status.allocatable.nvidia\.com/gpu}{"\n"}{end}' 2>/dev/null)"
  used="$(kubectl get pods -A --field-selector=status.phase!=Succeeded,status.phase!=Failed \
      -o jsonpath='{range .items[*]}{.spec.nodeName}{" "}{.metadata.deletionTimestamp}{"|"}{range .spec.containers[*]}{.resources.limits.nvidia\.com/gpu}{" "}{end}{"\n"}{end}' 2>/dev/null)"
  KD_ALLOC="$alloc" awk -F'|' '
      BEGIN{n=split(ENVIRON["KD_ALLOC"],l,"\n"); for(i=1;i<=n;i++){split(l[i],f,"|"); split(f[1],h," "); if(h[1]!="" && h[2]=="") a[h[1]]=f[2]+0}}
      { split($1,h," "); if (h[1]=="" || h[2]!="") next; m=split($2,g," "); for(i=1;i<=m;i++) u[h[1]]+=g[i] }
      END{ idle=0; for(k in a){ x=a[k]-u[k]; if(x>0) idle+=x }; print idle }' <<<"$used"
}

# events_since REASON SUBSTRING -> number of events (any namespace) with that
#   reason whose message contains SUBSTRING, last seen since the lesson started
events_since() {
  local start
  start="$(baseline_get start)"
  [[ -n "$start" ]] || { echo 0; return; }
  kubectl get events -A --field-selector "reason=$1" \
      -o jsonpath='{range .items[*]}{.lastTimestamp}{.eventTime}{"|"}{.message}{"\n"}{end}' 2>/dev/null \
    | awk -F'|' -v s="$start" -v sub_="$2" 'substr($1,1,19) >= substr(s,1,19) && index($2, sub_) > 0' | wc -l | tr -d ' '
}

# res_of KIND/NAME NS -> "replicas|resources of every container", for guards
res_of() {
  kubectl -n "$2" get "$1" -o jsonpath='{.spec.replicas}|{range .spec.template.spec.containers[*]}{.resources}{";"}{end}' 2>/dev/null
}

# pool_spec NAME -> the NodePool's spec as JSON (for "unchanged" guards)
pool_spec() { kubectl get nodepool "$1" -o jsonpath='{.spec}' 2>/dev/null; }

# ------------------------------------------------------------ verify checks ----

# check_karpenter_up  - the controller is running (scaling it down is not a fix)
check_karpenter_up() {
  check_eq "Karpenter controller is running" 1 "$(jp deploy/karpenter '{.status.readyReplicas}' -n "$KARP_NS")"
  why "kubectl -n $KARP_NS get deploy karpenter. (Broken install? kdrill course stop karpenter && kdrill course start karpenter)"
}

# check_only_karpenter_nodes  - every node besides the real k3d node was
#   launched by Karpenter and is backed by a NodeClaim (no hand-made nodes)
check_only_karpenter_nodes() {
  local claimed bad="" n
  claimed=" $(kubectl get nodeclaims -o jsonpath='{.items[*].status.nodeName}' 2>/dev/null) "
  for n in $(_karp_all_nodes); do
    [[ "$claimed" == *" $n "* ]] || bad+="$n "
  done
  check_eq "Every fake node was launched by Karpenter (has a NodeClaim)" "" "${bad% }"
  why "Don't create Node objects by hand; let Karpenter provision them. (kdrill reset starts over.)"
}

# check_pool_unchanged NAME KEY  - NodePool NAME still has the spec saved under KEY
check_pool_unchanged() {
  local want got
  want="$(baseline_get "$2")"; got="$(pool_spec "$1")"
  if [[ -n "$want" && "$want" == "$got" ]]; then _kd_ok "NodePool $1 is unchanged"
  else _kd_fail "NodePool $1 is unchanged"; fi
  why "NodePool $1 belongs to someone else; solve it on your side. (kdrill reset restores it.)"
}

# check_workload_unchanged KIND/NAME NS KEY  - replicas and resources as saved under KEY
check_workload_unchanged() {
  local want got
  want="$(baseline_get "$3")"; got="$(res_of "$1" "$2")"
  if [[ -n "$want" && "$want" == "$got" ]]; then _kd_ok "$1 keeps its replicas and resource requests"
  else _kd_fail "$1 keeps its replicas and resource requests" "expected: $want   got: ${got:-<missing>}"; fi
  why "Change where it runs, not how big it is. (kdrill reset restores it.)"
}
