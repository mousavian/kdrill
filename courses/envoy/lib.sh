# Helpers for the envoy course. Lesson scripts source this file:
#   source "$KDRILL_HOME/courses/envoy/lib.sh"
# common.sh (check, jp, wait_until, ...) is already loaded at that point.
# Written for bash 3.2: no associative arrays, no mapfile.
#
# This is the first course with real containers (kind real-light). The pieces
# that are not Envoy-specific (image pre-pull, client pod, traffic helpers,
# echo backends, test certificates) are written so they can move to
# base/lib/common.sh for later courses.

# ------------------------------------------------------------------ images ----
# Pinned, multi-arch (amd64 + arm64). The Envoy image is the exact build that
# Envoy Gateway v1.9.3 runs as its data plane, so Part A and Part B share it.
ENVOY_IMAGE=docker.io/envoyproxy/envoy:distroless-v1.39.5
WHOAMI_IMAGE=docker.io/traefik/whoami:v1.12.0
CURL_IMAGE=docker.io/curlimages/curl:8.22.0
LAB_IMAGES="$ENVOY_IMAGE $WHOAMI_IMAGE $CURL_IMAGE"
ENVOY_COURSE_DIR="$KDRILL_HOME/courses/envoy"

# prepull_images IMAGE... - pull images into the k3d node's containerd ahead of
# time so lesson setup does not wait on downloads. Best effort: if it fails,
# the kubelet pulls them on first use.
prepull_images() {
  local node="k3d-${KDRILL_CLUSTER:-kdrill}-server-0" img
  command -v docker >/dev/null 2>&1 || return 0
  for img in "$@"; do
    if ! docker exec "$node" crictl inspecti "$img" >/dev/null 2>&1; then
      info "pulling $img"
      docker exec "$node" crictl pull "$img" >/dev/null 2>&1 || info "(could not pre-pull $img; the kubelet will pull it)"
    fi
  done
  return 0
}

# ------------------------------------------------------------------ client ----
# client_up - the pod `client` (curl + the `hits` script) in the lesson
# namespace. Everything that sends traffic, in verify and in the READMEs, runs
# from here: there is no load balancer and NodePorts are not reachable from the
# host. A ConfigMap `lab-ca`, if it exists when the pod starts, is mounted at /certs.
client_up() {
  kubectl create configmap kdrill-client --from-file=hits="$ENVOY_COURSE_DIR/client/hits" \
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
    - {name: tools, mountPath: /usr/local/bin/hits, subPath: hits}
    - {name: ca, mountPath: /certs, readOnly: true}
  volumes:
  - name: tools
    configMap: {name: kdrill-client, defaultMode: 0755}
  - name: ca
    configMap: {name: lab-ca, optional: true}
YAML
}

# kx COMMAND... - run a command in the client pod.
kx() { kubectl exec client -- "$@" 2>/dev/null; }

# hits_out ARGS... - run `hits` in the client pod (same arguments as the
# learner uses: [-n N] [-c C] [-p] [-r HDR] URL [curl options]).
hits_out() { kubectl exec client -- hits "$@" 2>/dev/null; }

# count_of "STATUS WHO" OUTPUT - how many requests in a hits summary had that
# status and backend. WHO may be "*" (any backend); STATUS may be "*" too.
count_of() {
  printf '%s\n' "$2" | awk -v s="${1%% *}" -v w="${1#* }" \
    '{ if ((s=="*" || $2==s) && (w=="*" || $3==w)) t+=$1 } END { print t+0 }'
}

# whos OUTPUT - the distinct backends in a hits summary, sorted, space-separated.
whos() { printf '%s\n' "$1" | awk 'NF>=3 {print $3}' | sort -u | paste -sd' ' -; }

# http_code URL [curl options] - status code of one request (000 = no answer).
http_code() {
  local u="$1" c; shift
  c="$(kx curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@" "$u")"
  echo "${c:-000}"
}

# http_body URL [curl options] - body of one request.
http_body() { local u="$1"; shift; kx curl -s --max-time 15 "$@" "$u"; }

# http_head URL HEADER [curl options] - value of one response header.
http_head() {
  local u="$1" h="$2"; shift 2
  kx curl -s -o /dev/null -D - --max-time 15 "$@" "$u" | grep -i "^$h:" | tail -n 1 | cut -d: -f2- | sed 's/^ *//' | tr -d '\r'
}

# ------------------------------------------------------------- backends ----
# backend NAME [options] - an echo backend: traefik/whoami, which answers any
# path with its name, hostname and the request it received (method, path,
# headers). It also serves /health (status settable with POST) and waits before
# answering when called with ?wait=DURATION (e.g. ?wait=2s).
#   --replicas N      (default 1)
#   --name SHOWN      what it calls itself in "Name:" (default NAME)
#   --labels K=V,...  extra pod labels (e.g. app=echo to join another Service)
#   --headless        its Service is headless (clusterIP: None)
#   --no-service      no Service
#   --tls SECRET      serve HTTPS on 443 with tls.crt/tls.key from SECRET
#   --mtls            with --tls: also require client certificates signed by ca.crt in SECRET
#   --verbose         log every request it receives (kubectl logs)
backend() {
  local name="$1"; shift
  local replicas=1 shown="" labels="" svc=ClusterIP tls="" mtls="" verbose="" l
  shown="$name"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --replicas) replicas="$2"; shift 2 ;;
      --name) shown="$2"; shift 2 ;;
      --labels) labels="$2"; shift 2 ;;
      --headless) svc=None; shift ;;
      --no-service) svc=""; shift ;;
      --tls) tls="$2"; shift 2 ;;
      --mtls) mtls=1; shift ;;
      --verbose) verbose=1; shift ;;
      *) die "backend: unknown option $1" ;;
    esac
  done
  local label_yaml="        app: $name"$'\n'
  local IFS_old="$IFS"; IFS=','
  for l in $labels; do [[ -n "$l" ]] && label_yaml+="        ${l%%=*}: \"${l#*=}\""$'\n'; done
  IFS="$IFS_old"
  local port=80 args="" mounts="" vols=""
  if [[ -n "$tls" ]]; then
    port=443
    args="--port, \"443\", --cert, /tls/tls.crt, --key, /tls/tls.key${mtls:+, --cacert, /tls/ca.crt}"
    mounts="        volumeMounts: [{name: tls, mountPath: /tls, readOnly: true}]"
    vols="      volumes: [{name: tls, secret: {secretName: $tls}}]"
  fi
  [[ -n "$verbose" ]] && args="${args:+$args, }--verbose"
  [[ -n "$args" ]] && args="        args: [$args]"
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
$label_yaml
    spec:
      terminationGracePeriodSeconds: 1
      containers:
      - name: whoami
        image: $WHOAMI_IMAGE
${args}
        env: [{name: WHOAMI_NAME, value: "$shown"}]
        ports: [{name: http, containerPort: $port}]
        resources:
          requests: {cpu: 5m, memory: 8Mi}
          limits: {memory: 32Mi}
${mounts}
${vols}
YAML
  if [[ -n "$svc" ]]; then service "$name" "app=$name" ${tls:+--port 443} $([[ "$svc" == None ]] && echo --headless); fi
}

# broken_backend NAME [--labels K=V,...] - a pod that answers every request with
# 503 and "Name: broken" (a tiny Envoy with a direct_response). Give it the
# label of another backend's Service to put a bad endpoint behind that Service.
broken_backend() {
  local name="$1"; shift
  local labels="" l
  [[ "${1:-}" == --labels ]] && labels="$2"
  local label_yaml="        app: $name"$'\n'
  local IFS_old="$IFS"; IFS=','
  for l in $labels; do [[ -n "$l" ]] && label_yaml+="        ${l%%=*}: \"${l#*=}\""$'\n'; done
  IFS="$IFS_old"
  kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: $name
data:
  envoy.yaml: |
    static_resources:
      listeners:
      - name: broken
        address: {socket_address: {address: 0.0.0.0, port_value: 80}}
        filter_chains:
        - filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              stat_prefix: broken
              route_config:
                virtual_hosts:
                - name: all
                  domains: ["*"]
                  routes:
                  - match: {prefix: "/health"}
                    direct_response: {status: 200, body: {inline_string: "ok\n"}}
                  - match: {prefix: "/"}
                    direct_response: {status: 503, body: {inline_string: "Name: broken\nthis backend is broken\n"}}
              http_filters:
              - name: envoy.filters.http.router
                typed_config: {"@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $name
  labels: {app: $name}
spec:
  replicas: 1
  selector:
    matchLabels: {app: $name}
  template:
    metadata:
      labels:
$label_yaml
    spec:
      terminationGracePeriodSeconds: 1
      containers:
      - name: envoy
        image: $ENVOY_IMAGE
        args: [-c, /etc/envoy/envoy.yaml, --concurrency, "1", --log-level, warn]
        ports: [{name: http, containerPort: 80}]
        resources:
          requests: {cpu: 5m, memory: 24Mi}
          limits: {memory: 96Mi}
        volumeMounts: [{name: config, mountPath: /etc/envoy}]
      volumes: [{name: config, configMap: {name: $name}}]
YAML
}

# service NAME SELECTOR [--headless] [--port P] - a Service on port P (default 80)
# to target port "http". SELECTOR is K=V[,K=V].
service() {
  local name="$1" sel="$2"; shift 2
  local cip="" port=80 s sel_yaml=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --headless) cip="  clusterIP: None"; shift ;;
      --port) port="$2"; shift 2 ;;
      *) die "service: unknown option $1" ;;
    esac
  done
  local IFS_old="$IFS"; IFS=','
  for s in $sel; do sel_yaml+="    ${s%%=*}: \"${s#*=}\""$'\n'; done
  IFS="$IFS_old"
  kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Service
metadata:
  name: $name
spec:
$cip
  selector:
$sel_yaml
  ports:
  - {name: http, port: $port, targetPort: http}
YAML
}

# --------------------------------------------------------------- envoy ----
# envoy_up - Deployment + Service `envoy` running the lesson's ConfigMap
# `envoy` (key envoy.yaml). Ports: 10000 (HTTP listener), 10443 (TLS
# listener), 9901 (admin). A Secret `envoy-certs`, if present, is mounted at /certs.
# Envoy reads static config only at start: after changing the ConfigMap,
#   kubectl rollout restart deploy/envoy
envoy_up() {
  kubectl apply -f - >/dev/null <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: envoy
  labels: {app: envoy}
spec:
  replicas: 1
  strategy: {type: Recreate}
  selector:
    matchLabels: {app: envoy}
  template:
    metadata:
      labels: {app: envoy}
    spec:
      terminationGracePeriodSeconds: 2
      containers:
      - name: envoy
        image: $ENVOY_IMAGE
        args: [-c, /etc/envoy/envoy.yaml, --concurrency, "2", --service-cluster, lab, --service-node, envoy]
        ports:
        - {name: http, containerPort: 10000}
        - {name: https, containerPort: 10443}
        - {name: admin, containerPort: 9901}
        readinessProbe:
          httpGet: {path: /ready, port: 9901}
          periodSeconds: 2
        resources:
          requests: {cpu: 20m, memory: 32Mi}
          limits: {memory: 160Mi}
        volumeMounts:
        - {name: config, mountPath: /etc/envoy}
        - {name: certs, mountPath: /certs, readOnly: true}
      volumes:
      - {name: config, configMap: {name: envoy}}
      - {name: certs, secret: {secretName: envoy-certs, optional: true}}
---
apiVersion: v1
kind: Service
metadata:
  name: envoy
spec:
  selector: {app: envoy}
  ports:
  - {name: http, port: 10000, targetPort: 10000}
  - {name: https, port: 10443, targetPort: 10443}
  - {name: admin, port: 9901, targetPort: 9901}
YAML
}

# lab_wait DEPLOY... - wait until the client pod and the given Deployments are
# ready. The first lesson of the course pulls the images; later ones are fast.
lab_wait() {
  local d
  info "waiting for pods to be ready (the first run may pull images, up to a minute)..."
  kubectl wait pod/client --for=condition=Ready --timeout=180s >/dev/null || die "the client pod did not start (kubectl describe pod client)"
  for d in "$@"; do
    kubectl rollout status "deploy/$d" --timeout=180s >/dev/null || die "deploy/$d did not become ready (kubectl describe deploy $d)"
  done
}

# envoy_settle - before verify probes: the envoy rollout has finished and only
# one envoy pod (not terminating) remains.
_envoy_one_pod() {
  [[ "$(kubectl get pods -l app=envoy --no-headers -o custom-columns=D:.metadata.deletionTimestamp,R:.status.containerStatuses[0].ready 2>/dev/null | awk '$1=="<none>" && $2=="true"' | wc -l | tr -d ' ')" == 1 ]] &&
  [[ "$(kubectl get pods -l app=envoy --no-headers 2>/dev/null | wc -l | tr -d ' ')" == 1 ]]
}
_envoy_svc_ok() { [[ "$(kx curl -s --max-time 2 http://envoy:9901/ready)" == LIVE* ]]; }
_envoy_crashing() {   # a current (not terminating) envoy pod has already crashed at least once
  kubectl get pods -l app=envoy --no-headers -o custom-columns=D:.metadata.deletionTimestamp,R:.status.containerStatuses[0].restartCount 2>/dev/null \
    | awk '$1=="<none>" && $2+0>0 {f=1} END{exit !f}'
}
envoy_settle() {
  _envoy_crashing && ! _envoy_one_pod && return 0   # it won't come up by waiting
  wait_until 20 _envoy_one_pod || return 0
  # kube-proxy needs a moment after a restart to send Service traffic to the new pod.
  wait_until 15 _envoy_svc_ok || true
}

# envoy_ready - one envoy pod is running and ready.
envoy_ready() { _envoy_one_pod; }

# envoy_current - the running Envoy pod started after the last change to the
# ConfigMap envoy (i.e. it runs what the ConfigMap says).
envoy_current() {
  local cm="${1:-envoy}" changed started
  changed="$(kubectl get cm "$cm" -o jsonpath='{range .metadata.managedFields[*]}{.time}{"\n"}{end}' 2>/dev/null | sort | tail -n 1)"
  started="$(kubectl get pods -l app=envoy --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.status.startTime}{"\n"}{end}' 2>/dev/null | sort | tail -n 1)"
  [[ -n "$changed" && -n "$started" && ! "$started" < "$changed" ]]
}

# check_envoy_basics - the standard first checks of a Part A verify.
check_envoy_basics() {
  envoy_settle
  check "Envoy is running and ready (1 pod)" envoy_ready
  why "kubectl get pods -l app=envoy; kubectl logs deploy/envoy (a config error makes Envoy exit at start)"
  check "Envoy runs the current ConfigMap envoy (restarted after the last edit)" envoy_current
  why "Envoy reads static config only at start: kubectl rollout restart deploy/envoy"
}

# admin PATH - GET a path from Envoy's admin interface (envoy:9901), e.g. admin /clusters
admin() { kx curl -s --max-time 10 "http://envoy:9901$1"; }

# stat NAME - the value of one counter/gauge from /stats (exact name), 0 if absent.
stat() {
  local v
  v="$(admin "/stats?filter=^$(printf '%s' "$1" | sed 's/\./\\./g')\$" | awk -F': ' 'NR==1{print $2}')"
  echo "${v:-0}"
}

# cluster_hosts CLUSTER - "ip:port" of every host Envoy has in CLUSTER, sorted.
cluster_hosts() {
  admin /clusters | awk -F'::' -v c="$1" '$1==c && $3=="cx_active" {print $2}' | sort | paste -sd' ' -
}

# host_flags CLUSTER IP:PORT - the health_flags Envoy reports for a host.
host_flags() {
  admin /clusters | awk -F'::' -v c="$1" -v h="$2" '$1==c && $2==h && $3=="health_flags" {print $4}'
}

# pod_ips SELECTOR - IPs of the running, non-terminating pods matching SELECTOR, sorted.
pod_ips() {
  kubectl get pods -l "$1" --field-selector=status.phase=Running --no-headers \
    -o custom-columns=IP:.status.podIP,D:.metadata.deletionTimestamp 2>/dev/null | awk '$2=="<none>"{print $1}' | sort | paste -sd' ' -
}

# ------------------------------------------------------------ certificates ----
# Test PKI made with the host's openssl (OpenSSL or LibreSSL). Files go to a
# per-lesson directory under the kdrill state dir, never into the repo.
LAB_PKI="${KDRILL_STATE_DIR:-$HOME/.kdrill}/pki/${KDRILL_LESSON:-manual}"

# pki_ca - a CA (ca.crt/ca.key) in $LAB_PKI, created once per lesson run.
pki_ca() {
  mkdir -p "$LAB_PKI"
  [[ -s "$LAB_PKI/ca.crt" ]] && return 0
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -sha256 \
    -keyout "$LAB_PKI/ca.key" -out "$LAB_PKI/ca.crt" -subj "/CN=kdrill lab CA" >/dev/null 2>&1 \
    || die "openssl could not create the lab CA"
}

# pki_cert NAME CN [DNS...] - NAME.crt/NAME.key signed by the lab CA. With no
# DNS names, CN is used as the only SAN. Usable as server and client cert.
pki_cert() {
  local name="$1" cn="$2"; shift 2
  local sans="" d
  [[ $# -eq 0 ]] && set -- "$cn"
  for d in "$@"; do sans+="${sans:+,}DNS:$d"; done
  pki_ca
  printf '[req]\ndistinguished_name=dn\n[dn]\n[ext]\nsubjectAltName=%s\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth,clientAuth\nbasicConstraints=CA:FALSE\n' "$sans" > "$LAB_PKI/$name.cnf"
  openssl req -new -newkey rsa:2048 -nodes -keyout "$LAB_PKI/$name.key" -out "$LAB_PKI/$name.csr" \
    -subj "/CN=$cn" -config "$LAB_PKI/$name.cnf" >/dev/null 2>&1 || die "openssl: key/csr for $name failed"
  openssl x509 -req -in "$LAB_PKI/$name.csr" -CA "$LAB_PKI/ca.crt" -CAkey "$LAB_PKI/ca.key" -CAcreateserial \
    -days 825 -sha256 -extfile "$LAB_PKI/$name.cnf" -extensions ext -out "$LAB_PKI/$name.crt" >/dev/null 2>&1 \
    || die "openssl: signing $name failed"
}

# pki_fresh - forget this lesson's PKI (setup calls it so every run gets new certs).
pki_fresh() { rm -rf "$LAB_PKI"; }

# lab_ca_configmap - publish the CA certificate as ConfigMap lab-ca (key ca.crt);
# the client pod mounts it at /certs/ca.crt. Create it before client_up.
lab_ca_configmap() {
  kubectl create configmap lab-ca --from-file=ca.crt="$LAB_PKI/ca.crt" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

# tls_secret SECRET NAME [--ca] - a kubernetes.io/tls Secret from NAME.crt/key
# (plus ca.crt with --ca).
tls_secret() {
  local s="$1" n="$2"
  kubectl create secret tls "$s" --cert="$LAB_PKI/$n.crt" --key="$LAB_PKI/$n.key" --dry-run=client -o yaml \
    | kubectl apply -f - >/dev/null
  if [[ "${3:-}" == --ca ]]; then
    kubectl patch secret "$s" --type=merge -p "{\"data\":{\"ca.crt\":\"$(base64 < "$LAB_PKI/ca.crt" | tr -d '\n')\"}}" >/dev/null
  fi
}

# file_secret SECRET FILE... - a generic Secret with the given PKI files as keys.
file_secret() {
  local s="$1" f args=""; shift
  for f in "$@"; do args+=" --from-file=$f=$LAB_PKI/$f"; done
  kubectl create secret generic "$s" $args --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

# ----------------------------------------------------------------- JWTs ----
# Test tokens and the JWKS that verifies them (courses/envoy/assets/jwt).
JWT_DIR="$ENVOY_COURSE_DIR/assets/jwt"

# jwt_tokens_configmap - ConfigMap `tokens` with alice, bob, expired,
# wrong-aud and forged, so the learner can do
#   TOKEN=$(kubectl get cm tokens -o jsonpath='{.data.alice}')
jwt_tokens_configmap() {
  local args="" t
  for t in alice bob expired wrong-aud forged; do args+=" --from-literal=$t=$(tr -d '\n' < "$JWT_DIR/$t.jwt")"; done
  kubectl create configmap tokens $args --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

# token NAME - the raw token
token() { tr -d '\n' < "$JWT_DIR/$1.jwt"; }

# ------------------------------------------------------ Envoy Gateway ----
# Part B. The component runs Envoy Gateway in GatewayNamespace mode with a
# ClusterIP Service: a Gateway NAME in the lesson namespace gets a Deployment
# and a Service also called NAME there, so the client pod reaches it as
# http://NAME (port = listener port). The proxy's admin interface listens on
# 127.0.0.1:19000 inside the pod: use kubectl port-forward (gw_admin does).
GW_LABEL=gateway.envoyproxy.io/owning-gateway-name

# gw_cond GW TYPE - status of a Gateway condition (Accepted, Programmed)
gw_cond() { jp "gateway/$1" "{.status.conditions[?(@.type==\"$2\")].status}"; }
gw_programmed() { [[ "$(gw_cond "$1" Programmed)" == True ]]; }

# gw_pod GW - name of the (one, ready, not terminating) Envoy pod of a Gateway
gw_pod() {
  kubectl get pods -l "$GW_LABEL=$1" --no-headers \
    -o custom-columns=N:.metadata.name,D:.metadata.deletionTimestamp,R:.status.containerStatuses[0].ready 2>/dev/null \
    | awk '$2=="<none>" && $3=="true" {print $1; exit}'
}
_gw_up() { gw_programmed "$1" && [[ -n "$(gw_pod "$1")" ]] && [[ "$(kx curl -s -o /dev/null -w '%{http_code}' --max-time 2 "http://$1:${2:-80}/")" != 000 ]]; }

# gw_wait GW [SECONDS] [PORT] - setup: Gateway programmed, its Envoy ready and reachable.
gw_wait() {
  info "waiting for Gateway $1 and its Envoy (first time: image pull)..."
  wait_until "${2:-150}" _gw_up "$1" "${3:-80}" || die "Gateway $1 is not ready (kubectl describe gateway $1; kubectl get pods)"
}

# gw_settle GW [PORT] - verify: give a just-changed Gateway a moment.
gw_settle() {
  [[ "$(gw_cond "$1" Accepted)" == True ]] || return 0   # nobody is working on it: don't wait
  wait_until 30 _gw_up "$1" "${2:-80}" || true
}

# route_cond KIND/NAME TYPE - status of a route condition (Accepted, ResolvedRefs)
# for the route's first parentRef. Envoy Gateway can leave a stale status entry
# for a parentRef that was changed, so pick the entry matching the current spec.
route_cond() {
  local want
  want="$(jp "$1" '{.spec.parentRefs[0].name}/{.spec.parentRefs[0].sectionName}')"
  kubectl get "$1" -o jsonpath="{range .status.parents[*]}{.parentRef.name}/{.parentRef.sectionName}|{.conditions[?(@.type==\"$2\")].status}{\"\n\"}{end}" 2>/dev/null \
    | awk -F'|' -v w="$want" '$1==w {print $2; exit}'
}

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

# gw_stat GW NAME - one stat value (exact name) of the Gateway's Envoy, 0 if absent.
gw_stat() {
  local v
  v="$(gw_admin "$1" "/stats?filter=^$(printf '%s' "$2" | sed 's/\./\\./g')\$" | awk -F': ' 'NR==1{print $2}')"
  echo "${v:-0}"
}

# gw_wait_config GW RESOURCE TEXT [SECONDS] - poll the Gateway Envoy's
# /config_dump?resource=RESOURCE (e.g. dynamic_active_clusters) until it
# contains TEXT. A policy that changes a cluster replaces it, and the new
# cluster only becomes active once it has warmed (EDS), which can take ~15 s.
gw_wait_config() {
  local gw="$1" res="$2" text="$3"
  _gw_has() { gw_admin "$gw" "/config_dump?resource=$res" | grep -q "$text"; }
  wait_until "${4:-25}" _gw_has
}

# The client pod is lab equipment, not part of any task. A bare pod does not
# come back after a cluster restart (or if it is deleted by mistake), and then
# every traffic check would fail with no explanation, so verify recreates it.
_client_ok() { [[ "$(kubectl get pod client -o jsonpath='{.status.phase}' 2>/dev/null)" == Running ]]; }
if [[ "${KDRILL_PHASE:-}" == verify ]] && ! _client_ok; then
  echo "  (the client pod was missing; recreating it for the checks)"
  kubectl delete pod client --ignore-not-found --wait=true >/dev/null 2>&1 || true
  client_up >/dev/null 2>&1 || true
  kubectl wait pod/client --for=condition=Ready --timeout=90s >/dev/null 2>&1 || true
fi
