# Helpers for the kyverno course. Lesson scripts source this file:
#   source "$KDRILL_HOME/courses/kyverno/lib.sh"
# common.sh (fake_node, check, jp, ...) is already loaded at that point.
# Written for bash 3.2: no associative arrays, no mapfile.

KYV_VERSION=v1.19.2
# Where kdrill keeps its kubeconfig; we keep the kyverno CLI and lesson
# workspaces next to it (never inside the repo).
KYV_STATE="$(dirname "${KUBECONFIG:-$HOME/.kdrill/kubeconfig}")"
KYV_PROBE_DIR="$KDRILL_LESSON_DIR/probes"

# lesson_nodes - two plain fake worker nodes so lesson pods "run" without images.
lesson_nodes() {
  fake_node worker-1 --cpu 8 --mem 32Gi --label node.kubernetes.io/instance-type=m6i.2xlarge
  fake_node worker-2 --cpu 8 --mem 32Gi --label node.kubernetes.io/instance-type=m6i.2xlarge
  wait_nodes_ready
}

# kyv_wait_ready [SECONDS] - Kyverno's controllers are up (e.g. after a restart).
kyv_wait_ready() {
  local d
  for d in kyverno-admission-controller kyverno-background-controller kyverno-reports-controller; do
    kubectl -n kyverno wait deploy/$d --for=condition=Available --timeout="${1:-120}s" >/dev/null 2>&1 || return 1
  done
}

# kyv_apply FILE... - kubectl apply relative to the lesson dir, hiding
# Kyverno's "ClusterPolicy is deprecated" warning.
kyv_apply() {
  local f
  for f in "$@"; do kubectl apply -f "$KDRILL_LESSON_DIR/$f" >/dev/null 2>&1 || kubectl apply -f "$KDRILL_LESSON_DIR/$f" >/dev/null; done
}

# _all_policies_ready - every Kyverno policy of any kind reports Ready.
_all_policies_ready() {
  local bad
  bad="$( { kubectl get clusterpolicies.kyverno.io,policies.kyverno.io -A \
              -o jsonpath='{range .items[*]}{.metadata.name}={.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'
            kubectl get validatingpolicies.policies.kyverno.io \
              -o jsonpath='{range .items[*]}{.metadata.name}={.status.conditionStatus.ready}{"\n"}{end}'
          } 2>/dev/null | grep -v -e '=True$' -e '=true$' | grep -c .)"
  [[ "$bad" == 0 ]]
}

# kyv_settle - before verify probes: Kyverno is up, policies are Ready, and
# the webhook configuration has caught up with the latest policy change.
kyv_settle() {
  kyv_wait_ready 60 || true
  wait_until 30 _all_policies_ready || true
  sleep 3
}

# Background work (generate, mutate-existing, reports) takes a few seconds.
# wait_b SECONDS COMMAND... polls like wait_until, but all calls in one
# verify run share a budget of KYV_BUDGET seconds (default 60), so a lesson
# that is far from done fails in about a minute instead of timing out.
KYV_DEADLINE=""
wait_b() {
  local n="$1"; shift
  [[ -n "$KYV_DEADLINE" ]] || KYV_DEADLINE=$((SECONDS + ${KYV_BUDGET:-60}))
  local left=$((KYV_DEADLINE - SECONDS))
  (( left < 2 )) && left=2
  (( n > left )) && n=$left
  wait_until "$n" "$@"
}

# policy_ready NAME [KIND] - the policy (default clusterpolicy) is Ready.
policy_ready() {
  [[ "$(jp "${2:-clusterpolicy}/$1" '{.status.conditions[?(@.type=="Ready")].status}')" == True ]]
}

# dry_run FILE [NS] - server-side dry-run create of a probe manifest (path
# relative to the lesson's probes/ directory). Prints the server's answer.
dry_run() {
  kubectl create --dry-run=server -f "$KYV_PROBE_DIR/$1" ${2:+-n "$2"} -o yaml 2>&1
}

# _short OUTPUT - one line of a kubectl error, without the boilerplate prefix.
_short() {
  printf '%s' "$1" | grep -v '^Warning' | tr -s '\n' ' ' \
    | sed -e 's/^.*denied the request: //' -e 's/resource [A-Za-z]*\/[^ ]* was blocked due to the following policies *//' | cut -c1-260
}

# check_rejects DESC FILE MESSAGE [NS]
#   The probe must be rejected by a Kyverno policy, and the rejection must
#   contain MESSAGE (the policy's message, or the policy/rule name).
check_rejects() {
  local desc="$1" file="$2" msg="$3" out rc
  out="$(kubectl create --dry-run=server -f "$KYV_PROBE_DIR/$file" ${4:+-n "$4"} 2>&1)"; rc=$?
  if (( rc != 0 )) && [[ "$out" == *"blocked due to the following policies"* || "$out" == *"denied request"* || "$out" == *"denied the request"* ]] && [[ "$out" == *"$msg"* ]]; then
    _kd_ok "$desc"
  elif (( rc == 0 )); then
    _kd_fail "$desc" "probes/$file was admitted"
  else
    _kd_fail "$desc" "probes/$file was rejected, but not with \"$msg\": $(_short "$out")"
  fi
}

# check_admits DESC FILE [NS] - the probe must be admitted.
check_admits() {
  local desc="$1" file="$2" out rc
  out="$(kubectl create --dry-run=server -f "$KYV_PROBE_DIR/$file" ${3:+-n "$3"} 2>&1)"; rc=$?
  if (( rc == 0 )); then _kd_ok "$desc"
  else _kd_fail "$desc" "probes/$file was rejected: $(_short "$out")"; fi
}

# dr_get FILE JSONPATH [NS] - a field of the object as admission (incl. mutation) returns it.
dr_get() {
  kubectl create --dry-run=server -f "$KYV_PROBE_DIR/$1" ${3:+-n "$3"} -o jsonpath="$2" 2>/dev/null
}

# rule_actions POLICY -> "rule=Action ..." for each validate rule (Audit/Enforce,
#   taking the deprecated spec.validationFailureAction as fallback).
rule_actions() {
  local def
  def="$(jp "clusterpolicy/$1" '{.spec.validationFailureAction}')"
  kubectl get clusterpolicy "$1" -o jsonpath='{range .spec.rules[*]}{.name}={.validate.failureAction}{"\n"}{end}' 2>/dev/null \
    | awk -F= -v d="${def:-Audit}" '{a=$2; if(a=="") a=d; a=toupper(substr(a,1,1)) substr(a,2); print $1"="a}' | paste -sd' ' -
}

# policy_names [KIND] -> sorted names of all objects of KIND (default clusterpolicies)
policy_names() {
  kubectl get "${1:-clusterpolicies.kyverno.io}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | sort | paste -sd' ' -
}

# probe_ns NAME [LABELS...] - create a throw-away namespace (labelled for this
# lesson so cleanup removes it) with extra labels K=V.
probe_ns() {
  local n="$1"; shift
  if [[ -n "$(jp "ns/$n" '{.metadata.deletionTimestamp}')" ]]; then
    kubectl wait ns "$n" --for=delete --timeout=60s >/dev/null 2>&1
  fi
  kubectl create ns "$n" >/dev/null 2>&1
  kubectl label ns "$n" "$LESSON_LABEL_KEY=${KDRILL_LESSON:-manual}" "$@" --overwrite >/dev/null 2>&1
}

# kyv_cleanup - remove everything Kyverno-related the learner (or setup) may
# have created at cluster scope: ALL policies of every generation, exceptions,
# cluster reports and pending background requests. (The course README says so.)
kyv_cleanup() {
  local k
  for k in clusterpolicies.kyverno.io validatingpolicies.policies.kyverno.io mutatingpolicies.policies.kyverno.io \
           generatingpolicies.policies.kyverno.io imagevalidatingpolicies.policies.kyverno.io \
           deletingpolicies.policies.kyverno.io clustercleanuppolicies.kyverno.io globalcontextentries.kyverno.io; do
    kubectl delete "$k" --all --ignore-not-found --timeout=60s >/dev/null 2>&1 || true
  done
  for k in policies.kyverno.io policyexceptions.kyverno.io policyexceptions.policies.kyverno.io \
           namespacedvalidatingpolicies.policies.kyverno.io namespacedmutatingpolicies.policies.kyverno.io \
           namespacedgeneratingpolicies.policies.kyverno.io namespacedimagevalidatingpolicies.policies.kyverno.io \
           namespaceddeletingpolicies.policies.kyverno.io cleanuppolicies.kyverno.io; do
    kubectl delete "$k" --all -A --ignore-not-found --timeout=60s >/dev/null 2>&1 || true
  done
  kubectl delete clusterpolicyreports.wgpolicyk8s.io --all --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n kyverno delete updaterequests.kyverno.io --all --ignore-not-found --timeout=30s >/dev/null 2>&1 || true
  kubectl delete validatingadmissionpolicies,validatingadmissionpolicybindings -l app.kubernetes.io/managed-by=kyverno --ignore-not-found >/dev/null 2>&1 || true
  return 0
}

# ------------------------------------------------------------- kyverno CLI ----

# kyverno_cli -> path of the pinned kyverno CLI, downloading it on first use
# into the kdrill state directory (checksum-verified; nothing installed system-wide).
kyverno_cli() {
  local bin="$KYV_STATE/bin/kyverno" os arch sum file tmp
  if [[ -x "$bin" ]] && "$bin" version 2>/dev/null | grep -q "Version: ${KYV_VERSION#v}"; then echo "$bin"; return 0; fi
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"; arch="$(uname -m)"
  case "$os/$arch" in
    darwin/arm64)          sum=7915c03c613c22363a100adb3da8d06f2e2626d9d21a98b97f921795ffdc536f; arch=arm64 ;;
    darwin/x86_64)         sum=b645654ab8e65bd4aa64de9228e274b388bab19b3404a4e9af70174b3d5ad230 ;;
    linux/aarch64|linux/arm64) sum=250f2a02f143d5c6425e686b13c130d3a3ba7372dba6a7210d599d1b0dd12e92; arch=arm64 ;;
    linux/x86_64)          sum=357eaf1df8bc24ddd5a73979fadeaae6a032e8710f11af264229756e4956bf4a ;;
    *) echo "unsupported platform $os/$arch for the kyverno CLI" >&2; return 1 ;;
  esac
  file="kyverno-cli_${KYV_VERSION}_${os}_${arch}.tar.gz"
  mkdir -p "$KYV_STATE/bin"
  tmp="$(mktemp -d "$KYV_STATE/bin/dl.XXXXXX")"
  if ! curl -fsSL -o "$tmp/$file" "https://github.com/kyverno/kyverno/releases/download/${KYV_VERSION}/$file"; then
    rm -rf "$tmp"; echo "could not download the kyverno CLI" >&2; return 1
  fi
  if [[ "$(shasum -a 256 "$tmp/$file" 2>/dev/null || sha256sum "$tmp/$file")" != "$sum "* ]]; then
    rm -rf "$tmp"; echo "kyverno CLI checksum mismatch" >&2; return 1
  fi
  tar xzf "$tmp/$file" -C "$tmp" kyverno && mv "$tmp/kyverno" "$bin" && chmod +x "$bin"
  rm -rf "$tmp"
  echo "$bin"
}
