# Helpers for the training-platform course. Lesson scripts source this file:
#   source "$KDRILL_HOME/courses/training-platform/lib.sh"
# common.sh (check, jp, wait_until, ...) is already loaded at that point.
# Written for bash 3.2: no associative arrays, no mapfile.
#
# Every training pod runs kdrill.local/ml-tiny (base/images/ml-tiny): train,
# sample, prepare and mlt are on its PATH. verify reads results through a short
# helper pod `kdrill-inspect` that mounts the lesson's volumes and runs `mlt`.

ML_IMAGE="kdrill.local/ml-tiny:$(grep -m1 '^ML_TINY_VERSION=' "$KDRILL_HOME/base/images/ml-tiny/build.sh" | cut -d= -f2)"
# MinIO, built from source by Chainguard (upstream stopped publishing images);
# RELEASE.2026-11-12T01-15-23Z, arm64 + amd64, pinned by digest.
MINIO_IMAGE=docker.io/chainguard/minio@sha256:18c8fa28697b25e0f34c6faae171079e88a03efb8e76a21d3b5d07b4e3cbef3e
TR_DIR="$KDRILL_HOME/courses/training-platform"

# ------------------------------------------------------------ real nodes ----
# Pods of this course must run on the real k3s node. Fake (KWOK) nodes are
# normally removed with the sim lesson that made them; if one is left over,
# taint it so nothing of ours lands there.
guard_fake_nodes() {
  local n
  for n in $(kubectl get nodes -l type=kwok -o name 2>/dev/null) $(kubectl get nodes -l kwok.x-k8s.io/node=fake -o name 2>/dev/null); do
    kubectl taint "$n" kdrill.dev/fake=true:NoSchedule --overwrite >/dev/null 2>&1 || true
  done
  return 0
}

# ensure_ml_image - the ml-tiny image must be in the node's containerd (it is
# imported, never pulled). The kubelet's image garbage collection can remove it
# while no pod uses it when the node's disk is nearly full; import it again then.
ensure_ml_image() {
  local node="k3d-${KDRILL_CLUSTER:-kdrill}-server-0"
  command -v docker >/dev/null 2>&1 || return 0
  docker exec "$node" crictl inspecti "$ML_IMAGE" >/dev/null 2>&1 && return 0
  info "the image $ML_IMAGE is missing from the node (image garbage collection?); importing it again..."
  "$KDRILL_HOME/base/images/ml-tiny/build.sh" >/dev/null || die "could not import $ML_IMAGE"
}

# lesson_prep - first line of every lesson setup
lesson_prep() {
  guard_fake_nodes
  ensure_ml_image
}

# ------------------------------------------------------------------ jobs ----
# job_cond JOB TYPE -> "True" when the Job has that condition (Complete, Failed, Suspended, ...)
job_cond() { jp "job/$1" "{.status.conditions[?(@.type==\"$2\")].status}"; }
job_done() { [[ "$(job_cond "$1" Complete)" == True ]]; }
job_failed() { [[ "$(job_cond "$1" Failed)" == True ]]; }
# job_state JOB -> missing | complete | failed | suspended | running | pending
job_state() {
  if ! kubectl get job "$1" >/dev/null 2>&1; then echo missing; return; fi
  if job_done "$1"; then echo complete; return; fi
  if job_failed "$1"; then echo failed; return; fi
  if [[ "$(jp "job/$1" '{.spec.suspend}')" == true ]]; then echo suspended; return; fi
  if [[ "$(jp "job/$1" '{.status.active}')" =~ ^[1-9] ]]; then echo running; return; fi
  echo pending
}
# job_pods JOB -> pod names of a Job, oldest first
job_pods() {
  kubectl get pods -l "batch.kubernetes.io/job-name=$1" --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null
}
# job_logs JOB [CONTAINER] -> logs of the Job's newest pod
job_logs() {
  local p; p="$(job_pods "$1" | tail -n 1)"
  [[ -n "$p" ]] && kubectl logs "$p" ${2:+-c "$2"} 2>/dev/null
}
# all_job_logs JOB -> logs of every pod of the Job, oldest first
all_job_logs() {
  local p
  for p in $(job_pods "$1"); do kubectl logs "$p" -c train 2>/dev/null || kubectl logs "$p" 2>/dev/null; done
}
# final_loss LOGS -> the final_loss= value of a finished run ("" if none)
final_loss() { printf '%s\n' "$1" | sed -n 's/.*done: step [0-9]* final_loss=\([0-9.]*\).*/\1/p' | tail -n 1; }
# last_step LOGS -> the newest "step N/M" in the logs
last_step() { printf '%s\n' "$1" | sed -n 's/.* step \([0-9]*\)\/[0-9]* loss.*/\1/p' | tail -n 1; }
# float_lt A B -> success when A < B
float_lt() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a != "" && a+0 < b+0)}'; }
# env_of RESOURCE NAME [CONTAINER_INDEX] -> literal value of an env var in a pod template
env_of() { jp "$1" "{.spec.template.spec.containers[${3:-0}].env[?(@.name==\"$2\")].value}"; }
# exit_codes JOB -> "reason:code" of the train container of every pod of the Job
exit_codes() {
  local p
  for p in $(job_pods "$1"); do
    jp "pod/$p" '{range .status.containerStatuses[*]}{.state.terminated.reason}:{.state.terminated.exitCode}{" "}{end}'
  done
}

# progress_msg JOB -> "step 120/600" from the newest pod's log, or the pod phase
progress_msg() {
  local l s
  l="$(job_logs "$1")"; s="$(printf '%s\n' "$l" | sed -n 's/.* step \([0-9]*\/[0-9]*\) loss.*/\1/p' | tail -n 1)"
  if [[ -n "$s" ]]; then echo "at step $s"; else echo "starting"; fi
}

# wait_job JOB SECONDS -> poll until the Job is complete or failed (returns 0 either way when it ends)
wait_job() {
  local end=$((SECONDS + $2)) s
  while (( SECONDS < end )); do
    s="$(job_state "$1")"
    [[ "$s" == complete || "$s" == failed ]] && return 0
    sleep 2
  done
  return 1
}

# ------------------------------------------------------------- inspect pod ----
# inspect_up [--s3 SECRET] PVC... - (re)create the pod kdrill-inspect that
# mounts each PVC read-only at /mnt/<pvc>. It runs the ml-tiny image (mlt,
# python) and is removed again with inspect_down so it never pins a volume.
inspect_up() {
  local s3="" vols="" mounts="" envs="" p want have
  if [[ "${1:-}" == --s3 ]]; then s3="$2"; shift 2; fi
  want="$* ${s3:+s3=$s3}"
  have="$(jp pod/kdrill-inspect '{.metadata.annotations.kdrill\.dev/mounts}' || true)"
  if [[ -n "$have" && "$have" == "$want" && "$(jp pod/kdrill-inspect '{.status.phase}{.metadata.deletionTimestamp}')" == Running ]]; then return 0; fi
  kubectl delete pod kdrill-inspect --ignore-not-found --grace-period=0 --force >/dev/null 2>&1
  for p in "$@"; do
    vols+="  - {name: $p, persistentVolumeClaim: {claimName: $p, readOnly: true}}"$'\n'
    mounts+="    - {name: $p, mountPath: /mnt/$p, readOnly: true}"$'\n'
  done
  if [[ -n "$mounts" ]]; then mounts=$'\n'"${mounts%$'\n'}"; vols=$'\n'"${vols%$'\n'}"; else mounts=" []"; vols=" []"; fi
  [[ -n "$s3" ]] && envs="    envFrom: [{secretRef: {name: $s3}}]"$'\n'"    env: [{name: AWS_ENDPOINT_URL, value: 'http://minio:9000'}]"$'\n'
  kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: kdrill-inspect
  labels: {app: kdrill-inspect}
  annotations: {kdrill.dev/mounts: "$want"}
spec:
  terminationGracePeriodSeconds: 0
  restartPolicy: Never
  containers:
  - name: inspect
    image: $ML_IMAGE
    command: [sleep, "900"]
    resources:
      requests: {cpu: 10m, memory: 16Mi}
      limits: {memory: 256Mi}
${envs}    volumeMounts:${mounts}
  volumes:${vols}
YAML
  kubectl wait pod/kdrill-inspect --for=condition=Ready --timeout=60s >/dev/null 2>&1
}
inspect_down() { kubectl delete pod kdrill-inspect --ignore-not-found --wait=false >/dev/null 2>&1; return 0; }
# ix COMMAND... - run a command in the inspect pod
ix() { kubectl exec kdrill-inspect -- "$@" 2>/dev/null; }
# mget FILE KEY... - values from a JSON file (dotted keys, see mlt), one per line
mget() { ix mlt get "$@"; }
# mget1 FILE KEY - one value
mget1() { mget "$1" "$2" | head -n 1; }

# ------------------------------------------------------------- baselines ----
# Remember a value at setup time (in a ConfigMap of the lesson namespace) to
# compare against in verify.
baseline_set() {
  if kubectl get configmap kdrill-baseline >/dev/null 2>&1; then
    kubectl patch configmap kdrill-baseline --type merge -p "{\"data\":{\"$1\":\"$2\"}}" >/dev/null
  else
    kubectl create configmap kdrill-baseline --from-literal="$1=$2" >/dev/null
  fi
}
baseline_get() { jp configmap/kdrill-baseline "{.data.$1}"; }

# ---------------------------------------------------------------- eviction ----
# evict POD - ask the Eviction API to evict a pod (what `kubectl drain` does).
# The pod gets the DisruptionTarget condition, then SIGTERM.
evict() {
  kubectl create --raw "/api/v1/namespaces/$KDRILL_NS/pods/$1/eviction" -f - >/dev/null <<JSON
{"apiVersion":"policy/v1","kind":"Eviction","metadata":{"name":"$1","namespace":"$KDRILL_NS"}}
JSON
}
# running_pod_of JOB -> name of the Job's Running pod (newest)
running_pod_of() {
  kubectl get pods -l "batch.kubernetes.io/job-name=$1" --field-selector=status.phase=Running \
    --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | tail -n 1
}
# pod_step POD -> newest step logged by a pod (0 if none yet)
pod_step() {
  local s; s="$(kubectl logs "$1" 2>/dev/null | sed -n 's/.* step \([0-9]*\)\/[0-9]* loss.*/\1/p' | tail -n 1)"
  echo "${s:-0}"
}

# ------------------------------------------------------------------ kueue ----
# apply_labelled FILE - apply a lesson manifest and label every object in it
# with the lesson label, so cleanup also removes the cluster-scoped ones.
apply_labelled() {
  kubectl apply -f "$KDRILL_LESSON_DIR/$1" >/dev/null
  kubectl label -f "$KDRILL_LESSON_DIR/$1" "$LESSON_LABEL_KEY=$KDRILL_LESSON" --overwrite >/dev/null
}
# wl_of OWNER_KIND OWNER_NAME -> name of the Kueue Workload owned by a Job or JobSet
wl_of() {
  kubectl get workloads.kueue.x-k8s.io -o jsonpath="{range .items[?(@.metadata.ownerReferences[0].name==\"$2\")]}{.metadata.ownerReferences[0].kind}/{.metadata.name}{\"\\n\"}{end}" 2>/dev/null \
    | awk -F/ -v k="$1" '$1==k {print $2}' | head -n 1
}
# wl_cond WORKLOAD TYPE -> status of a Workload condition
wl_cond() { jp "workloads.kueue.x-k8s.io/$1" "{.status.conditions[?(@.type==\"$2\")].status}"; }
# wl_time WORKLOAD TYPE -> lastTransitionTime of a Workload condition
wl_time() { jp "workloads.kueue.x-k8s.io/$1" "{.status.conditions[?(@.type==\"$2\")].lastTransitionTime}"; }
# kueue_cleanup CQ... -- FLAVOR... - delete lesson Kueue objects (cluster-scoped ones carry the lesson label anyway)
kueue_cleanup() {
  kubectl delete workloads.kueue.x-k8s.io --all -n "$KDRILL_NS" --ignore-not-found --timeout=30s >/dev/null 2>&1 || true
  kubectl delete localqueues.kueue.x-k8s.io --all -n "$KDRILL_NS" --ignore-not-found --timeout=30s >/dev/null 2>&1 || true
  kubectl delete clusterqueues.kueue.x-k8s.io,resourceflavors.kueue.x-k8s.io,workloadpriorityclasses.kueue.x-k8s.io \
    -l "$LESSON_LABEL_KEY" --ignore-not-found --timeout=60s >/dev/null 2>&1 || true
  return 0
}

# ---------------------------------------------------------------- minio ----
# minio_up - a single MinIO pod + Service `minio` (API on 9000) in the lesson
# namespace, root credentials from Secret minio-root, bucket(s) created.
minio_up() {
  kubectl create secret generic minio-root --from-literal=MINIO_ROOT_USER=kdrill-admin \
    --from-literal=MINIO_ROOT_PASSWORD=kdrill-admin-secret --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl apply -f - >/dev/null <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  labels: {app: minio}
spec:
  replicas: 1
  strategy: {type: Recreate}
  selector:
    matchLabels: {app: minio}
  template:
    metadata:
      labels: {app: minio}
    spec:
      terminationGracePeriodSeconds: 2
      containers:
      - name: minio
        image: $MINIO_IMAGE
        args: [server, /data, --address, ":9000", --console-address, ":9001"]
        envFrom: [{secretRef: {name: minio-root}}]
        env:
        - {name: MINIO_BROWSER, value: "off"}
        - {name: GOMAXPROCS, value: "1"}
        ports: [{name: s3, containerPort: 9000}]
        readinessProbe: {httpGet: {path: /minio/health/ready, port: 9000}, periodSeconds: 2}
        resources:
          requests: {cpu: 50m, memory: 96Mi}
          limits: {memory: 384Mi}
        volumeMounts: [{name: data, mountPath: /data}]
      volumes:
      - name: data
        emptyDir: {sizeLimit: 512Mi}
---
apiVersion: v1
kind: Service
metadata: {name: minio}
spec:
  selector: {app: minio}
  ports: [{name: s3, port: 9000, targetPort: s3}]
YAML
  kubectl rollout status deploy/minio --timeout=120s >/dev/null || die "MinIO did not start"
}
# s3_admin COMMAND... - run a command with the MinIO root credentials in a short pod
s3_admin() {
  kubectl run "kdrill-s3-$$-$RANDOM" --rm -i --restart=Never --quiet --image="$ML_IMAGE" \
    --overrides='{"spec":{"containers":[{"name":"s3","image":"'"$ML_IMAGE"'","command":["sh","-c","export AWS_ACCESS_KEY_ID=$MINIO_ROOT_USER AWS_SECRET_ACCESS_KEY=$MINIO_ROOT_PASSWORD AWS_ENDPOINT_URL=http://minio:9000; exec \"$@\"","_"],"args":'"$(printf '%s\n' "$@" | python_json_list)"',"envFrom":[{"secretRef":{"name":"minio-root"}}],"resources":{"requests":{"cpu":"10m","memory":"64Mi"},"limits":{"memory":"256Mi"}}}]}}' \
    2>/dev/null
}
# python_json_list - stdin lines -> a JSON list of strings (no python needed on the host)
python_json_list() {
  awk 'BEGIN{printf "["} {gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); printf "%s\"%s\"", (NR>1?",":""), $0} END{printf "]"}'
}
