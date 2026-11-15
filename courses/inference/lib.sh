# Helpers for the inference course. Lesson scripts source this file:
#   source "$KDRILL_HOME/courses/inference/lib.sh"
# common.sh (check, jp, wait_until, fake_node, ...) is already loaded at that point.
# Written for bash 3.2: no associative arrays, no mapfile.
#
# Three kinds of "model server" are used (every README says which):
#   llama   the real llama.cpp HTTP server with SmolLM2-135M on CPU (Part A)
#   sim     llm-d-inference-sim, a vLLM look-alike with vLLM metric names (Parts B-D)
#   fake    pods on KWOK fake GPU nodes that never serve a request (Part D)

# ------------------------------------------------------------------ images ----
# Pinned by digest, arm64 + amd64. The inference-models component pulls them
# into the node (crictl pull <digest>) so lessons never wait on a registry.
LLAMA_IMAGE=ghcr.io/ggml-org/llama.cpp@sha256:c7d58273d753d33a352e5c41ab300c5ae040a16fa4b202231bb606478065c124   # server-b12375
SIM_IMAGE=ghcr.io/llm-d/llm-d-inference-sim@sha256:9992453829c0dea8d120b8e0322bb0e4237cbb3c6d9ea3bdce060410c40c91c9  # v1.2.0
EPP_IMAGE=ghcr.io/llm-d/llm-d-router-endpoint-picker@sha256:024188e998f516879f68532016ca24fabca00afbdcc2af9a61b17634e197df2c  # v1.0.0
PYTHON_IMAGE=docker.io/library/python@sha256:9ef1a599f863231c3d91e941389bfdc4a2d6070557243d54df1a4e57015b960e  # 3.13-alpine
CURL_IMAGE=docker.io/curlimages/curl:8.22.0
MODEL_IMAGE=kdrill.local/smollm2-135m:q4km
MODEL_NODE_DIR=/var/lib/kdrill/models
MODEL_FILE=smollm2-135m-instruct-q4_k_m.gguf
INF_COURSE_DIR="$KDRILL_HOME/courses/inference"
LAB_IMAGES="$LLAMA_IMAGE $SIM_IMAGE $EPP_IMAGE $PYTHON_IMAGE $CURL_IMAGE"

# prepull_images IMAGE... - pull into the node's containerd (best effort).
prepull_images() {
  local node="k3d-${KDRILL_CLUSTER:-kdrill}-server-0" img
  command -v docker >/dev/null 2>&1 || return 0
  for img in "$@"; do
    if ! docker exec "$node" crictl inspecti "$img" >/dev/null 2>&1; then
      info "pulling ${img%%@*}"
      docker exec "$node" crictl pull "$img" >/dev/null 2>&1 || info "(could not pre-pull $img; the kubelet will pull it)"
    fi
  done
  return 0
}

# ------------------------------------------------------------------ client ----
# client_up - the pod `client` (curl + the `ask` script) in the lesson namespace.
# All traffic in verify and in the READMEs is sent from here: the lab has no load
# balancer and port-forward breaks long streams.
client_up() {
  kubectl create configmap kdrill-ask --from-file=ask="$INF_COURSE_DIR/client/ask" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  if kubectl get pod client >/dev/null 2>&1; then return 0; fi
  kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: client
  labels: {app: client}
spec:
  terminationGracePeriodSeconds: 1
  containers:
  - name: curl
    image: $CURL_IMAGE
    command: [sh, -c, "trap 'exit 0' TERM; while true; do sleep 1; done"]
    resources:
      requests: {cpu: 5m, memory: 8Mi}
      limits: {memory: 64Mi}
    volumeMounts:
    - {name: tools, mountPath: /usr/local/bin/ask, subPath: ask}
  volumes:
  - name: tools
    configMap: {name: kdrill-ask, defaultMode: 0755}
YAML
}

# kx COMMAND... - run a command in the client pod (stderr dropped).
kx() { kubectl exec client -- "$@" 2>/dev/null; }
# ask_out ARGS... - run `ask` in the client pod (see courses/inference/client/ask).
ask_out() { kubectl exec client -- ask "$@" 2>/dev/null; }

# count_of "STATUS WHO" OUTPUT - how many requests in an ask/hits summary had
# that status and WHO. WHO and STATUS may be "*".
count_of() {
  printf '%s\n' "$2" | awk -v s="${1%% *}" -v w="${1#* }" \
    '{ if ((s=="*" || $2==s) && (w=="*" || $3==w)) t+=$1 } END { print t+0 }'
}
# count_matching REGEX OUTPUT - total count of summary lines "N STATUS WHO" whose "STATUS WHO" matches REGEX.
count_matching() {
  printf '%s\n' "$2" | awk -v re="$1" '{ k=$2" "$3; if (k ~ re) t+=$1 } END { print t+0 }'
}
# whos OUTPUT - the distinct WHO values of a summary, sorted, space-separated.
whos() { printf '%s\n' "$1" | awk 'NF>=3 {print $3}' | sort -u | paste -sd' ' -; }
# verbose_who OUTPUT - for "ask -v" output (STATUS WHO TTFB TOTAL): count per WHO, "who:count ..." sorted.
share_by() { printf '%s\n' "$1" | awk '$1=="200"{c[$2]++} END{for(k in c) print k":"c[k]}' | sort | paste -sd' ' -; }

# http_code URL [curl options] - status code of one request (000 = no answer).
http_code() {
  local u="$1" c; shift
  c="$(kx curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@" "$u")"
  echo "${c:-000}"
}
# http_body URL [curl options] - body of one request.
http_body() { local u="$1"; shift; kx curl -s --max-time 30 "$@" "$u"; }

# ------------------------------------------------------------- simulator ----
# sim_deploy NAME [options] - a Deployment and a Service NAME (port 80 -> 8000)
# of llm-d-inference-sim, plus a headless Service NAME-pods (what the metrics
# aggregator resolves). Pods carry app=NAME and llm-d.ai/engine-type=vllm, report
# their name in the response header x-inference-pod, and expose vLLM metrics.
#   --replicas N       (default 1)
#   --model M          served model name (default tiny)
#   (the simulator runs in echo mode: the answer repeats the prompt, so the number
#    of generated tokens is min(max_tokens, prompt tokens) and request durations are predictable)
#   --seqs N           max-num-seqs: requests running at once (default 4)
#   --ttft D           time to first token (default 100ms)
#   --itl D            inter-token latency (default 20ms)
#   --startup D        startup-duration: /health/ready answers 503 this long (default 0s)
#   --lora A,B         LoRA adapters loaded (names), with max-loras 2
#   --labels K=V,...   extra pod labels
#   --args "..."       extra simulator arguments
#   --cpu QTY          cpu request (default 10m)   --mem QTY  memory request (default 24Mi)
#   --no-service       only the Deployment
#   --gpu N            request nvidia.com/gpu: N (Part D, KWOK nodes)
sim_deploy() {
  local name="$1"; shift
  local replicas=1 model=tiny seqs=4 ttft=100ms itl=20ms startup=0s lora="" labels="" extra="" cpu=10m mem=24Mi svc=1 gpu="" l
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --replicas) replicas="$2"; shift 2 ;;
      --model) model="$2"; shift 2 ;;
      --seqs) seqs="$2"; shift 2 ;;
      --ttft) ttft="$2"; shift 2 ;;
      --itl) itl="$2"; shift 2 ;;
      --startup) startup="$2"; shift 2 ;;
      --lora) lora="$2"; shift 2 ;;
      --labels) labels="$2"; shift 2 ;;
      --args) extra="$2"; shift 2 ;;
      --cpu) cpu="$2"; shift 2 ;;
      --mem) mem="$2"; shift 2 ;;
      --no-service) svc=""; shift ;;
      --gpu) gpu="$2"; shift 2 ;;
      *) die "sim_deploy: unknown option $1" ;;
    esac
  done
  local label_yaml="" args="" IFS_old="$IFS" a
  IFS=','; for l in $labels; do [[ -n "$l" ]] && label_yaml+="        ${l%%=*}: \"${l#*=}\""$'\n'; done; IFS="$IFS_old"
  args="--model, $model, --mode, echo, --port, \"8000\", --max-num-seqs, \"$seqs\", --time-to-first-token, $ttft, --inter-token-latency, $itl"
  [[ "$startup" != 0s ]] && args+=", --startup-duration, $startup"
  if [[ -n "$lora" ]]; then
    args+=", --max-loras, \"2\", --lora-modules"
    IFS=','; for l in $lora; do args+=", '{\"name\": \"$l\"}'"; done; IFS="$IFS_old"
  fi
  for a in $extra; do args+=", \"$a\""; done
  local res="requests: {cpu: $cpu, memory: $mem}" lim=""
  [[ -n "$gpu" ]] && { res="requests: {cpu: $cpu, memory: $mem}"; lim="          limits: {nvidia.com/gpu: \"$gpu\"}"$'\n'; }
  kubectl apply -f - >/dev/null <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $name
  labels: {app: $name}
spec:
  replicas: $replicas
  selector:
    matchLabels: {app: $name}
  template:
    metadata:
      labels:
        app: $name
        llm-d.ai/engine-type: vllm
${label_yaml}
    spec:
      terminationGracePeriodSeconds: 1
      containers:
      - name: sim
        image: $SIM_IMAGE
        args: [$args]
        env:
        - {name: POD_NAME, valueFrom: {fieldRef: {fieldPath: metadata.name}}}
        - {name: POD_IP, valueFrom: {fieldRef: {fieldPath: status.podIP}}}
        ports: [{name: http, containerPort: 8000}]
        readinessProbe: {httpGet: {path: /health/ready, port: 8000}, periodSeconds: 2}
        resources:
          $res
${lim}
YAML
  if [[ -n "$svc" ]]; then
    kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Service
metadata: {name: $name}
spec:
  selector: {app: $name}
  ports: [{name: http, port: 80, targetPort: http}]
---
apiVersion: v1
kind: Service
metadata: {name: $name-pods}
spec:
  clusterIP: None
  selector: {app: $name}
  ports: [{name: http, port: 8000}]
YAML
  fi
}

# sim_admin IP JSON - POST JSON to the simulator's /admin/config on a pod (from the client pod).
sim_admin() { kx curl -s -X POST "http://$1:8000/admin/config" -H 'content-type: application/json' -d "$2" >/dev/null; }

# pod_ips SELECTOR - IPs of the Running, non-terminating pods matching SELECTOR, sorted, space-separated.
pod_ips() {
  kubectl get pods -l "$1" --field-selector=status.phase=Running --no-headers \
    -o custom-columns=IP:.status.podIP,D:.metadata.deletionTimestamp 2>/dev/null | awk '$2=="<none>"{print $1}' | sort | paste -sd' ' -
}
# pod_names SELECTOR - names of the Running, non-terminating pods matching SELECTOR, sorted.
pod_names() {
  kubectl get pods -l "$1" --field-selector=status.phase=Running --no-headers \
    -o custom-columns=N:.metadata.name,D:.metadata.deletionTimestamp 2>/dev/null | awk '$2=="<none>"{print $1}' | sort | paste -sd' ' -
}
# pod_ip NAME
pod_ip() { jp "pod/$1" '{.status.podIP}'; }

# metric IP:PORT NAME - the value of one (unlabelled-sum) Prometheus metric from a pod, 0 if absent.
metric() {
  local v
  v="$(kx curl -s --max-time 5 "http://$1/metrics" | awk -v n="$2" '$1==n || index($1, n"{")==1 {s+=$NF; f=1} END{if(f) printf "%s", s}')"
  echo "${v:-0}"
}

# ------------------------------------------------------- metrics aggregator ----
# aggregator_up HEADLESS_SERVICE [PORT] - Deployment + Service `aggregator`: the
# stand-in for Prometheus that turns every pod's /metrics into one JSON document
# KEDA can read (courses/inference/assets/aggregator.py).
aggregator_up() {
  kubectl create configmap aggregator --from-file=aggregator.py="$INF_COURSE_DIR/assets/aggregator.py" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl apply -f - >/dev/null <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aggregator
  labels: {app: aggregator}
spec:
  replicas: 1
  selector:
    matchLabels: {app: aggregator}
  template:
    metadata:
      labels: {app: aggregator}
    spec:
      terminationGracePeriodSeconds: 1
      containers:
      - name: aggregator
        image: $PYTHON_IMAGE
        command: [python3, /app/aggregator.py]
        env:
        - {name: TARGET_HOST, value: "$1"}
        - {name: TARGET_PORT, value: "${2:-8000}"}
        ports: [{containerPort: 8080}]
        readinessProbe: {httpGet: {path: /, port: 8080}, periodSeconds: 2}
        resources:
          requests: {cpu: 5m, memory: 16Mi}
          limits: {memory: 64Mi}
        volumeMounts: [{name: app, mountPath: /app}]
      volumes: [{name: app, configMap: {name: aggregator}}]
---
apiVersion: v1
kind: Service
metadata: {name: aggregator}
spec:
  selector: {app: aggregator}
  ports: [{name: http, port: 80, targetPort: 8080}]
YAML
}
# agg FIELD - one number from the aggregator's JSON (running, waiting, inflight, replicas, waiting_per_replica, kv_cache_max).
agg() {
  kx curl -s --max-time 5 http://aggregator/ | sed -n "s/.*\"$1\": *\([0-9.eE+-]*\).*/\1/p" | head -n 1
}

# --------------------------------------------------------------- load ----
# load_up NAME CONCURRENCY URL [ask options...] - a Deployment `NAME` whose pod
# keeps CONCURRENCY chat requests in flight against URL until it is deleted
# (an endless `ask`). Its output is not read.
load_up() {
  local name="$1" conc="$2" url="$3"; shift 3
  local opts="" o
  for o in "$@"; do opts+=", \"$o\""; done
  kubectl apply -f - >/dev/null <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $name
  labels: {app: $name, kdrill.dev/role: load}
spec:
  replicas: 1
  selector:
    matchLabels: {app: $name}
  template:
    metadata:
      labels: {app: $name, kdrill.dev/role: load}
    spec:
      terminationGracePeriodSeconds: 1
      containers:
      - name: load
        image: $CURL_IMAGE
        command: [ask, -n, "10000000", -c, "$conc"${opts}, "$url"]
        resources:
          requests: {cpu: 10m, memory: 8Mi}
          limits: {memory: 64Mi}
        volumeMounts:
        - {name: tools, mountPath: /usr/local/bin/ask, subPath: ask}
      volumes:
      - name: tools
        configMap: {name: kdrill-ask, defaultMode: 0755}
YAML
}
# load_down NAME...
load_down() { local n; for n in "$@"; do kubectl delete deploy "$n" --ignore-not-found --wait=false >/dev/null 2>&1; done; }

# ------------------------------------------------------------ real server ----
# llama_deploy NAME [options] - the real llama.cpp server on the lesson's weights
# (hostPath on the node), a Deployment and a Service NAME (80 -> 8080).
#   --replicas N  --threads N (default 2)  --ctx N (default 2048)  --parallel N (default 2)
#   --mem QTY (limit, default 512Mi)  --cpu QTY (limit, default 2)  --no-metrics
llama_deploy() {
  local name="$1"; shift
  local replicas=1 threads=2 ctx=2048 par=2 mem=512Mi cpu=2 metrics="--metrics, "
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --replicas) replicas="$2"; shift 2 ;;
      --threads) threads="$2"; shift 2 ;;
      --ctx) ctx="$2"; shift 2 ;;
      --parallel) par="$2"; shift 2 ;;
      --mem) mem="$2"; shift 2 ;;
      --cpu) cpu="$2"; shift 2 ;;
      --no-metrics) metrics=""; shift ;;
      *) die "llama_deploy: unknown option $1" ;;
    esac
  done
  kubectl apply -f - >/dev/null <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $name
  labels: {app: $name}
spec:
  replicas: $replicas
  selector:
    matchLabels: {app: $name}
  template:
    metadata:
      labels: {app: $name}
    spec:
      terminationGracePeriodSeconds: 5
      containers:
      - name: llama
        image: $LLAMA_IMAGE
        args: [-m, /models/$MODEL_FILE, --alias, tiny, ${metrics}-c, "$ctx", --parallel, "$par", -t, "$threads"]
        ports: [{name: http, containerPort: 8080}]
        readinessProbe: {httpGet: {path: /health, port: 8080}, periodSeconds: 2}
        resources:
          requests: {cpu: 100m, memory: 160Mi}
          limits: {cpu: "$cpu", memory: $mem}
        volumeMounts: [{name: models, mountPath: /models, readOnly: true}]
      volumes: [{name: models, hostPath: {path: $MODEL_NODE_DIR, type: Directory}}]
---
apiVersion: v1
kind: Service
metadata: {name: $name}
spec:
  selector: {app: $name}
  ports: [{name: http, port: 80, targetPort: http}]
YAML
}

# --------------------------------------------------------- waiting helpers ----
# lab_wait DEPLOY... - wait until the client pod and the given Deployments are ready.
lab_wait() {
  local d
  info "waiting for pods to be ready (the first run may pull images, up to a minute)..."
  kubectl wait pod/client --for=condition=Ready --timeout=180s >/dev/null || die "the client pod did not start (kubectl describe pod client)"
  for d in "$@"; do
    kubectl rollout status "deploy/$d" --timeout=240s >/dev/null || die "deploy/$d did not become ready (kubectl describe deploy $d)"
  done
}

# ready_pods SELECTOR - number of Ready, non-terminating pods matching SELECTOR.
ready_pods() {
  kubectl get pods -l "$1" --no-headers \
    -o custom-columns=D:.metadata.deletionTimestamp,R:.status.containerStatuses[0].ready 2>/dev/null \
    | awk '$1=="<none>" && $2=="true"' | wc -l | tr -d ' '
}
# restarts SELECTOR - total container restarts of the pods matching SELECTOR.
restarts() {
  kubectl get pods -l "$1" -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>/dev/null \
    | awk '{t+=$1} END{print t+0}'
}
# current_hash DEPLOY - pod-template-hash of the Deployment's newest ReplicaSet (label app=DEPLOY).
current_hash() {
  local rev
  rev="$(jp "deploy/$1" '{.metadata.annotations.deployment\.kubernetes\.io/revision}')"
  kubectl get rs -l "app=$1" -o jsonpath='{range .items[*]}{.metadata.annotations.deployment\.kubernetes\.io/revision} {.metadata.labels.pod-template-hash}{"\n"}{end}' 2>/dev/null \
    | awk -v r="$rev" '$1==r {print $2; exit}'
}
# settle DEPLOY [SECONDS] [COUNT] - verify: wait until COUNT (default: spec.replicas)
# pods of the Deployment's CURRENT ReplicaSet (label app=DEPLOY) are ready, but
# give up at once when such a pod is crash-looping (waiting would not help).
# Old pods are ignored.
settle() {
  local end=$((SECONDS + ${2:-45})) h want="${3:-$(jp "deploy/$1" '{.spec.replicas}')}"
  while (( SECONDS < end )); do
    h="$(current_hash "$1")"
    if [[ -n "$h" ]]; then
      [[ "$(ready_pods "app=$1,pod-template-hash=$h")" -ge "${want:-1}" ]] && return 0
      [[ "$(restarts "app=$1,pod-template-hash=$h")" -gt 0 ]] && return 1
    fi
    sleep 1
  done
  return 1
}
# svc_endpoints SERVICE - number of ready endpoint addresses behind a Service.
svc_endpoints() {
  kubectl get endpointslices -l "kubernetes.io/service-name=$1" \
    -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}' 2>/dev/null | grep -c . || true
}
# chat_ok SERVICE_URL [MODEL] - succeeds when one tiny chat completion answers 200 with a non-empty choices array.
chat_ok() {
  local out
  out="$(kx curl -s --max-time 30 -w '\n%{http_code}' "$1" -H 'content-type: application/json' \
    -d "{\"model\":\"${2:-tiny}\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hi.\"}],\"max_tokens\":8}")"
  [[ "$(printf '%s' "$out" | tail -n 1)" == 200 && "$out" == *'"choices"'* ]]
}

# ---------------------------------------------------------- Envoy Gateway ----
# The component runs Envoy Gateway in GatewayNamespace mode with a ClusterIP
# Service: Gateway NAME in the lesson namespace gets a Deployment and a Service
# NAME there, so the client reaches it as http://NAME.
GW_LABEL=gateway.envoyproxy.io/owning-gateway-name
gw_cond() { jp "gateway/$1" "{.status.conditions[?(@.type==\"$2\")].status}"; }
gw_programmed() { [[ "$(gw_cond "$1" Programmed)" == True ]]; }
gw_pod() {
  kubectl get pods -l "$GW_LABEL=$1" --no-headers \
    -o custom-columns=N:.metadata.name,D:.metadata.deletionTimestamp,R:.status.containerStatuses[0].ready 2>/dev/null \
    | awk '$2=="<none>" && $3=="true" {print $1; exit}'
}
_gw_up() { gw_programmed "$1" && [[ -n "$(gw_pod "$1")" ]] && [[ "$(kx curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://$1:${2:-80}/")" != 000 ]]; }
# gw_wait GW [SECONDS] [PORT] - setup: Gateway programmed, its Envoy ready and reachable.
gw_wait() {
  info "waiting for Gateway $1 and its Envoy (first time: image pull)..."
  wait_until "${2:-150}" _gw_up "$1" "${3:-80}" || die "Gateway $1 is not ready (kubectl describe gateway $1; kubectl get pods)"
}
# gw_settle GW [PORT] - verify: give a just-changed Gateway a moment.
gw_settle() {
  [[ "$(gw_cond "$1" Accepted)" == True ]] || return 0
  wait_until 30 _gw_up "$1" "${2:-80}" || true
}
# route_cond KIND/NAME TYPE - status of a route condition for the route's first parentRef.
route_cond() {
  local want
  want="$(jp "$1" '{.spec.parentRefs[0].name}/{.spec.parentRefs[0].sectionName}')"
  kubectl get "$1" -o jsonpath="{range .status.parents[*]}{.parentRef.name}/{.parentRef.sectionName}|{.conditions[?(@.type==\"$2\")].status}{\"\n\"}{end}" 2>/dev/null \
    | awk -F'|' -v w="$want" '$1==w {print $2; exit}'
}
# policy_cond KIND/NAME TYPE - status of a policy's Accepted condition (first ancestor).
policy_cond() { jp "$1" "{.status.ancestors[0].conditions[?(@.type==\"$2\")].status}"; }
# gw_admin GW PATH - GET PATH from the admin interface of the Gateway's Envoy (via port-forward).
gw_admin() {
  local pod port pf out
  pod="$(gw_pod "$1")"; [[ -n "$pod" ]] || return 1
  port=$(( 20000 + RANDOM % 20000 ))
  kubectl port-forward "pod/$pod" "$port:19000" >/dev/null 2>&1 &
  pf=$!
  wait_until 8 curl -s -o /dev/null "http://127.0.0.1:$port/ready"
  out="$(curl -s --max-time 10 "http://127.0.0.1:$port$2")"
  kill "$pf" >/dev/null 2>&1; wait "$pf" 2>/dev/null
  printf '%s' "$out"
}
# gw_wait_config GW RESOURCE TEXT [SECONDS] - poll /config_dump?resource=RESOURCE until it contains TEXT.
gw_wait_config() {
  local gw="$1" res="$2" text="$3"
  _gw_has() { gw_admin "$gw" "/config_dump?resource=$res" | grep -q "$text"; }
  wait_until "${4:-25}" _gw_has
}

# ---------------------------------------------------- endpoint picker (EPP) ----
# epp_up POOL [options] - the llm-d router endpoint picker for the InferencePool
# POOL (pods labelled app=POOL, port 8000): ServiceAccount + Role, ConfigMap
# `epp-config`, Deployment and Service `epp` (ext_proc, plain h2c on 9002), and
# the InferencePool itself. Same objects the llm-d-router Helm chart renders,
# trimmed for this lab (TLS off, 200 ms metrics refresh, small requests).
#   --plugins FILE      EndpointPickerConfig to use instead of the default
#                       (queue depth + KV-cache utilisation), a path under the lesson dir
#   --gates LIST        --feature-gates value (e.g. flowControl=true)
#   --name NAME         name of the picker Deployment/Service (default epp)
#   --selector K=V      pod label selecting the pool (default app=POOL)
epp_up() {
  local pool="$1"; shift
  local plugins="" gates="" name=epp sel="app=$pool"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --plugins) plugins="$2"; shift 2 ;;
      --gates) gates="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --selector) sel="$2"; shift 2 ;;
      *) die "epp_up: unknown option $1" ;;
    esac
  done
  local cfg
  if [[ -n "$plugins" ]]; then cfg="$(sed 's/^/    /' "$KDRILL_LESSON_DIR/$plugins")"; else
    cfg="$(sed 's/^/    /' "$INF_COURSE_DIR/assets/epp-default.yaml")"
  fi
  local gate_arg=""
  [[ -n "$gates" ]] && gate_arg=", --feature-gates=$gates"
  kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: ServiceAccount
metadata: {name: $name}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: $name}
rules:
- apiGroups: ["llm-d.ai"]
  resources: ["inferenceobjectives", "inferencemodelrewrites"]
  verbs: ["get", "watch", "list"]
- apiGroups: ["inference.networking.k8s.io"]
  resources: ["inferencepools"]
  verbs: ["get", "watch", "list"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: $name}
subjects: [{kind: ServiceAccount, name: $name}]
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: $name}
---
apiVersion: v1
kind: ConfigMap
metadata: {name: $name-config}
data:
  plugins.yaml: |
$cfg
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $name
  labels: {app: $name}
spec:
  replicas: 1
  strategy: {type: Recreate}
  selector:
    matchLabels: {app: $name}
  template:
    metadata:
      labels: {app: $name}
    spec:
      serviceAccountName: $name
      terminationGracePeriodSeconds: 5
      containers:
      - name: epp
        image: $EPP_IMAGE
        args: [--pool-name, $pool, --pool-namespace, "$KDRILL_NS", --pool-group, inference.networking.k8s.io, --config-file, /config/plugins.yaml, --grpc-health-port, "9003", --secure-serving=false, --metrics-endpoint-auth=false, --tracing=false, --refresh-metrics-interval=200ms${gate_arg}]
        env:
        - {name: NAMESPACE, valueFrom: {fieldRef: {fieldPath: metadata.namespace}}}
        - {name: POD_NAME, valueFrom: {fieldRef: {fieldPath: metadata.name}}}
        ports: [{name: grpc, containerPort: 9002}, {name: health, containerPort: 9003}, {name: metrics, containerPort: 9090}]
        readinessProbe: {grpc: {port: 9003, service: readiness}, periodSeconds: 2}
        resources:
          requests: {cpu: 20m, memory: 64Mi}
          limits: {memory: 256Mi}
        volumeMounts: [{name: cfg, mountPath: /config}]
      volumes: [{name: cfg, configMap: {name: $name-config}}]
---
apiVersion: v1
kind: Service
metadata: {name: $name}
spec:
  selector: {app: $name}
  ports:
  - {name: grpc-ext-proc, port: 9002, appProtocol: kubernetes.io/h2c}
  - {name: http-metrics, port: 9090}
---
apiVersion: inference.networking.k8s.io/v1
kind: InferencePool
metadata: {name: $pool}
spec:
  targetPorts: [{number: 8000}]
  selector: {matchLabels: {${sel%%=*}: "${sel#*=}"}}
  endpointPickerRef: {name: $name, port: {number: 9002}, failureMode: FailOpen}
YAML
}

# epp_active URL - succeeds when the Gateway's Envoy currently calls the endpoint picker: the picker adds
# the response header x-went-into-resp-headers. Used to wait until a new policy has reached Envoy.
epp_active() {
  kx curl -s -D - -o /dev/null --max-time 10 "$1" -H 'content-type: application/json' \
    -d "{\"model\":\"${2:-tiny}\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":4}" | grep -qi '^x-went-into-resp-headers'
}

# ------------------------------------------------------------- fake GPUs ----
# Part D lessons (kind: sim) use the fake-GPU helpers of the gpu-scheduling
# course: gpu_node, baseline_save, check_fleet_unchanged, live_count, res_limit,
# fake_node_count, wl_state, ... Source both libraries:
#   source "$KDRILL_HOME/courses/inference/lib.sh"
#   source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
# fleet_settle - call after wait_nodes_ready and before baseline_save: KWOK adds a few labels
# (beta.kubernetes.io/*) to a fake node shortly after it becomes Ready, and the baseline must include them.
_fleet_labelled() { [[ "$(kubectl get nodes -l type=kwok --no-headers -o custom-columns=L:.metadata.labels 2>/dev/null | grep -vc 'beta.kubernetes.io/os')" == 0 ]]; }
fleet_settle() { wait_until 30 _fleet_labelled || true; sleep 2; }
