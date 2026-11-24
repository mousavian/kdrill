# Helpers for the istio course. Lesson scripts source this file:
#   source "$KDRILL_HOME/courses/istio/lib.sh"
# common.sh (check, jp, wait_until, ...) is already loaded at that point.
# Written for bash 3.2: no associative arrays, no mapfile.
#
# Traffic checks run curl inside "client" Deployments of the lesson (image
# curlimages/curl, container name "curl"), so requests really travel through
# the client's sidecar, the mesh and the server's sidecar.

source "$KDRILL_HOME/base/components/istio/istioctl.sh"
IST_TIMEOUT="${IST_TIMEOUT:-5}"     # curl --max-time per request, seconds

# ist_wait_ready [SECONDS] - istiod, the CNI agent and ztunnel are up.
ist_wait_ready() {
  local t="${1:-120}"
  kubectl -n istio-system wait deploy/istiod --for=condition=Available --timeout="${t}s" >/dev/null 2>&1 || return 1
  kubectl -n istio-system rollout status ds/istio-cni-node --timeout="${t}s" >/dev/null 2>&1 || return 1
  kubectl -n istio-system rollout status ds/ztunnel --timeout="${t}s" >/dev/null 2>&1 || return 1
}

# ist_setup_start - common start of every setup.sh: Istio is up, and the
# workloads can only land on the real node (sidecars need real containers).
ist_setup_start() {
  ist_wait_ready 180 || die "Istio is not ready (kubectl -n istio-system get pods); try: kdrill course stop istio && kdrill course start istio"
  local fake
  fake="$( { kubectl get nodes -l type=kwok -o name; kubectl get nodes -l kwok.x-k8s.io/node=fake -o name; } 2>/dev/null | sort -u | paste -sd' ' -)"
  if [[ -n "$fake" ]]; then
    die "fake (KWOK) nodes from a sim course are still in the cluster: $fake
  Istio lessons need real containers on the k3d node. Remove them first:
    kubectl delete node $fake"
  fi
}

# mesh_ns NS... - turn on sidecar injection for namespaces.
mesh_ns() {
  local n
  for n in "$@"; do kubectl label ns "$n" istio-injection=enabled --overwrite >/dev/null; done
}

# rollouts NS DEPLOY... - wait for Deployments (never fails the script).
rollouts() {
  local ns="$1" d; shift
  for d in "$@"; do kubectl -n "$ns" rollout status "deploy/$d" --timeout=150s >/dev/null 2>&1 || true; done
}

# rollouts_all NS - wait for every Deployment in a namespace.
rollouts_all() {
  local ns="$1" d
  for d in $(kubectl -n "$ns" get deploy -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    kubectl -n "$ns" rollout status "deploy/$d" --timeout=150s >/dev/null 2>&1 || true
  done
}

# settle [SECONDS] - give istiod a moment to push the latest config to the proxies.
settle() { sleep "${1:-3}"; }

# await_code SECONDS CODE NS FROM URL [CURL_ARGS...] - poll until the request
# gets status CODE (istiod usually pushes within 1-2 s, sometimes slower).
# Never fails: the checks that follow report the real state.
await_code() {
  local t="$1" want="$2"; shift 2
  local end=$((SECONDS + t))
  until [[ "$(http_code "$@")" == "$want" ]]; do
    (( SECONDS >= end )) && break
    sleep 1
  done
  return 0
}

# --------------------------------------------------------------- traffic ----

# in_client NS DEPLOY CMD... - run a command in the "curl" container of a client.
in_client() {
  local ns="$1" d="$2"; shift 2
  kubectl -n "$ns" exec "deploy/$d" -c curl -- "$@" 2>/dev/null
}

# http_code NS FROM URL [CURL_ARGS...] -> HTTP status, or 000 if there was no
# HTTP answer (connection refused/reset, timeout).
http_code() {
  local ns="$1" from="$2" url="$3" out; shift 3
  out="$(in_client "$ns" "$from" curl -s -o /dev/null -m "$IST_TIMEOUT" -w '%{http_code}' "$@" "$url")"
  echo "${out:-000}"
}

# http_body NS FROM URL [CURL_ARGS...] -> response body (empty on failure).
http_body() {
  local ns="$1" from="$2" url="$3"; shift 3
  in_client "$ns" "$from" curl -s -m "$IST_TIMEOUT" "$@" "$url"
}

# http_headers NS FROM URL [CURL_ARGS...] -> response status line + headers,
# lower-cased header names.
http_headers() {
  local ns="$1" from="$2" url="$3"; shift 3
  in_client "$ns" "$from" curl -s -m "$IST_TIMEOUT" -o /dev/null -D - "$@" "$url" \
    | tr -d '\r' | awk -F': ' 'NF>1{print tolower($1)": "$2; next}{print}'
}

# http_time NS FROM URL [CURL_ARGS...] -> "CODE SECONDS" (seconds as a decimal).
http_time() {
  local ns="$1" from="$2" url="$3" out; shift 3
  out="$(in_client "$ns" "$from" curl -s -o /dev/null -m "${IST_TIMEOUT}" -w '%{http_code} %{time_total}' "$@" "$url")"
  echo "${out:-000 99}"
}

# codes NS FROM URL N [CURL_ARGS...] -> sorted "code:count" words for N
# sequential requests, e.g. "200:48 500:2" (000 = no HTTP answer).
codes() {
  local ns="$1" from="$2" url="$3" n="$4"; shift 4
  in_client "$ns" "$from" sh -c '
    n="$1"; url="$2"; shift 2; i=0
    while [ "$i" -lt "$n" ]; do
      curl -s -o /dev/null -m '"$IST_TIMEOUT"' -w "%{http_code}\n" "$@" "$url"; i=$((i+1))
    done' _ "$n" "$url" "$@" | sort | uniq -c | awk '{print $2":"$1}' | paste -sd' ' -
}

# backends NS FROM URL N [CURL_ARGS...] -> which Deployment answered N
# sequential requests, as sorted "deployment:count" words, e.g.
# "catalog-v1:80 catalog-v2:20". URL must hit go-httpbin's /hostname
# endpoint (the backends run with USE_REAL_HOSTNAME=true, so it returns the
# pod name). A request that got no hostname back counts as "error".
backends() {
  local ns="$1" from="$2" url="$3" n="$4"; shift 4
  in_client "$ns" "$from" sh -c '
    n="$1"; url="$2"; shift 2; i=0
    while [ "$i" -lt "$n" ]; do
      h="$(curl -s -m '"$IST_TIMEOUT"' "$@" "$url" | sed -n "s/.*\"hostname\": *\"\([^\"]*\)\".*/\1/p")"
      echo "${h:-error}"; i=$((i+1))
    done' _ "$n" "$url" "$@" \
    | sed -E 's/-[a-z0-9]{5,10}-[a-z0-9]{5}$//' | sort | uniq -c | awk '{print $2":"$1}' | paste -sd' ' -
}

# count_of KEY "k:v k:v ..." -> v for KEY (0 if absent)
count_of() {
  local w
  for w in $2; do [[ "${w%:*}" == "$1" ]] && { echo "${w##*:}"; return 0; }; done
  echo 0
}

# between LOW HIGH VALUE - integer range check
between() { [[ "$3" =~ ^[0-9]+$ ]] && (( $3 >= $1 && $3 <= $2 )); }

# faster_than SECONDS VALUE - decimal comparison (VALUE < SECONDS)
faster_than() { awk -v a="$2" -v b="$1" 'BEGIN{exit !(a+0 < b+0)}'; }

# --------------------------------------------------------------- sidecars ----

# pod_has_sidecar NS POD - the pod runs an istio-proxy (native sidecar in
# initContainers, or a classic container).
pod_has_sidecar() {
  [[ " $(jp "pod/$2" '{.spec.initContainers[*].name} {.spec.containers[*].name}' -n "$1") " == *" istio-proxy "* ]]
}

# live_pods NS SELECTOR -> names of pods that are not terminating
live_pods() {
  kubectl -n "$1" get pods -l "$2" -o jsonpath='{range .items[*]}{.metadata.name} {.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null \
    | awk 'NF==1{print $1}'
}

# sidecar_state NS SELECTOR -> "all" (every live pod has a sidecar and is
# Ready), "none" (no live pod has one), "mixed", or "nopods".
sidecar_state() {
  local ns="$1" sel="$2" p with=0 without=0 notready=0
  for p in $(live_pods "$ns" "$sel"); do
    if pod_has_sidecar "$ns" "$p"; then with=$((with+1)); else without=$((without+1)); fi
    [[ "$(jp "pod/$p" '{.status.conditions[?(@.type=="Ready")].status}' -n "$ns")" == True ]] || notready=$((notready+1))
  done
  if (( with + without == 0 )); then echo nopods
  elif (( without == 0 && notready == 0 )); then echo all
  elif (( with == 0 )); then echo none
  else echo mixed; fi
}

# proxy_admin NS DEPLOY PATH - GET from the Envoy admin API of a sidecar
# (via pilot-agent), e.g. proxy_admin shop web "stats?filter=retry".
proxy_admin() {
  kubectl -n "$1" exec "deploy/$2" -c istio-proxy -- pilot-agent request GET "$3" 2>/dev/null
}

# -------------------------------------------------------------- cleanup ----

# ist_cleanup - remove Istio config the learner may have created in
# istio-system (mesh-wide policies would affect the next lesson). Lesson
# namespaces, and everything in them, are deleted by kdrill itself.
ist_cleanup() {
  local k
  for k in peerauthentications.security.istio.io authorizationpolicies.security.istio.io \
           requestauthentications.security.istio.io telemetries.telemetry.istio.io \
           sidecars.networking.istio.io envoyfilters.networking.istio.io \
           virtualservices.networking.istio.io destinationrules.networking.istio.io \
           serviceentries.networking.istio.io gateways.networking.istio.io; do
    kubectl -n istio-system delete "$k" --all --ignore-not-found --timeout=30s >/dev/null 2>&1 || true
  done
  return 0
}
