# Karpenter with its KWOK cloud provider: the real Karpenter controller, but the
# "instances" it launches are KWOK fake nodes. Used by the karpenter course.
#
# No official image is published for the KWOK provider, so we build one from
# the pinned upstream tag:
#   1. shallow-clone kubernetes-sigs/karpenter at KARPENTER_VERSION into a cache
#      directory (~/.cache/kdrill/src/karpenter-<version>)
#   2. apply kwok-node-capacity.patch (one line: fake nodes report the instance
#      type's capacity instead of the sum of the pod requests that triggered
#      them, so NodePool limits and `kubectl describe node` look like a cloud's)
#   3. cross-compile ./kwok with the host Go toolchain (CGO off, linux/<docker arch>)
#      - or inside a golang container when Go is not installed
#   4. wrap the binary in a distroless image, kdrill.local/karpenter-kwok:<version>-kdrill.<rev>
#   5. k3d image import it into this cluster
# Steps 1-4 are skipped when the image is already in the local Docker image
# store, so reinstalling (course stop/start, a new cluster) takes seconds.
# The chart is rendered from the same checkout with `helm template`.
#
# Instance types come from catalog.txt (next to this script), converted to the
# provider's JSON format and mounted from ConfigMap karpenter/instance-types.
KARPENTER_VERSION="${KARPENTER_VERSION:-v1.15.1}"
DISTROLESS="${DISTROLESS:-gcr.io/distroless/static-debian12:nonroot}"
GO_IMAGE="${GO_IMAGE:-golang:1.26}"
NS=karpenter
PATCH_REV=1                                   # bump when the patch changes
IMG="kdrill.local/karpenter-kwok:${KARPENTER_VERSION}-kdrill.${PATCH_REV}"
COMP_DIR="$KDRILL_HOME/base/components/karpenter-kwok"
CACHE="${KDRILL_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/kdrill}"
SRC="$CACHE/src/karpenter-${KARPENTER_VERSION}"
CLUSTER="${KDRILL_CLUSTER:-kdrill}"

command -v helm >/dev/null || die "karpenter-kwok needs helm to render the chart: brew install helm"
command -v git >/dev/null || die "karpenter-kwok needs git"

# --- source -----------------------------------------------------------------
if [[ ! -f "$SRC/kwok/main.go" ]]; then
  info "fetching karpenter ${KARPENTER_VERSION} source (shallow clone)..."
  rm -rf "$SRC.tmp"; mkdir -p "$(dirname "$SRC")"
  git -c advice.detachedHead=false clone -q --depth 1 --branch "$KARPENTER_VERSION" \
    https://github.com/kubernetes-sigs/karpenter "$SRC.tmp"
  mv "$SRC.tmp" "$SRC"
fi
if ! git -C "$SRC" apply -R --check "$COMP_DIR/kwok-node-capacity.patch" 2>/dev/null; then
  git -C "$SRC" apply "$COMP_DIR/kwok-node-capacity.patch" || die "could not apply kwok-node-capacity.patch to $SRC"
fi

# --- image --------------------------------------------------------------------
if ! docker image inspect "$IMG" >/dev/null 2>&1; then
  case "$(docker info -f '{{.Architecture}}')" in
    aarch64|arm64) arch=arm64 ;;
    x86_64|amd64)  arch=amd64 ;;
    *) die "unsupported docker architecture $(docker info -f '{{.Architecture}}')" ;;
  esac
  build="$CACHE/build/karpenter-kwok-${KARPENTER_VERSION}"
  rm -rf "$build"; mkdir -p "$build"
  start=$SECONDS
  if command -v go >/dev/null; then
    info "building the karpenter KWOK provider (go, linux/$arch; first time takes a few minutes)..."
    ( cd "$SRC" && CGO_ENABLED=0 GOOS=linux GOARCH="$arch" GOTOOLCHAIN=auto \
        go build -trimpath -ldflags "-s -w" -o "$build/controller" ./kwok ) >"$build/log" 2>&1 || {
      tail -30 "$build/log" >&2; die "go build failed"; }
  else
    info "building the karpenter KWOK provider in $GO_IMAGE (no local Go; slow and memory hungry)..."
    docker run --rm -v "$SRC:/src:ro" -v "$build:/out" -w /src \
      -e CGO_ENABLED=0 -e GOOS=linux -e GOARCH="$arch" -e GOFLAGS=-buildvcs=false \
      "$GO_IMAGE" go build -trimpath -ldflags "-s -w" -o /out/controller ./kwok
  fi
  printf 'FROM %s\nCOPY controller /ko-app/controller\nENTRYPOINT ["/ko-app/controller"]\n' "$DISTROLESS" > "$build/Dockerfile"
  docker build -q --platform "linux/$arch" -t "$IMG" "$build" >/dev/null
  rm -rf "$build"
  info "built $IMG in $((SECONDS - start))s"
fi
if ! docker exec "k3d-${CLUSTER}-server-0" crictl inspecti "$IMG" >/dev/null 2>&1; then
  k3d image import -c "$CLUSTER" "$IMG" >/dev/null 2>&1 || die "k3d image import -c $CLUSTER $IMG failed"
fi

# --- instance-type catalogue ----------------------------------------------------
# catalog.txt -> the KWOK provider's JSON. Each offering carries capacity type,
# zone, and the AWS-style labels Karpenter should know before launch
# (instance-category, instance-gpu-name/-count/-manufacturer); "DoesNotExist"
# on CPU types makes a GPU requirement exclude them, as on AWS.
catalog_json() {
  awk '
    BEGIN { split("us-west-2a us-west-2b us-west-2c", Z, " "); split("0.31 0.36 0.40", F, " "); n = 0 }
    /^#/ || NF < 8 { next }
    {
      name=$1; arch=$2; cpu=$3; mem=$4; gpus=$5; model=$6; od=$7; offers=$8
      fam=name; sub(/\..*/, "", fam); cat=substr(fam, 1, 1); fi++
      if (gpus > 0) { gpu = sprintf("{\"key\":\"karpenter.k8s.aws/instance-gpu-name\",\"operator\":\"In\",\"values\":[\"%s\"]},{\"key\":\"karpenter.k8s.aws/instance-gpu-count\",\"operator\":\"In\",\"values\":[\"%s\"]},{\"key\":\"karpenter.k8s.aws/instance-gpu-manufacturer\",\"operator\":\"In\",\"values\":[\"nvidia\"]}", tolower(model), gpus) }
      else { gpu = "{\"key\":\"karpenter.k8s.aws/instance-gpu-name\",\"operator\":\"DoesNotExist\"},{\"key\":\"karpenter.k8s.aws/instance-gpu-count\",\"operator\":\"DoesNotExist\"},{\"key\":\"karpenter.k8s.aws/instance-gpu-manufacturer\",\"operator\":\"DoesNotExist\"}" }
      o = ""
      for (z = 1; z <= 3; z++) {
        split(offers, kinds, ",")
        for (k in kinds) {
          ct = (kinds[k] == "od") ? "on-demand" : "spot"
          price = (ct == "on-demand") ? od : od * F[((fi + z) % 3) + 1]
          o = o (o == "" ? "" : ",") sprintf("{\"Price\":%.4f,\"Available\":true,\"Requirements\":[{\"key\":\"karpenter.sh/capacity-type\",\"operator\":\"In\",\"values\":[\"%s\"]},{\"key\":\"topology.kubernetes.io/zone\",\"operator\":\"In\",\"values\":[\"%s\"]},{\"key\":\"karpenter.k8s.aws/instance-category\",\"operator\":\"In\",\"values\":[\"%s\"]},%s]}", price, ct, Z[z], cat, gpu)
        }
      }
      res = sprintf("\"cpu\":\"%s\",\"memory\":\"%sGi\",\"pods\":\"110\",\"ephemeral-storage\":\"100Gi\"", cpu, mem)
      if (gpus > 0) res = res sprintf(",\"nvidia.com/gpu\":\"%s\"", gpus)
      printf "%s{\"name\":\"%s\",\"architecture\":\"%s\",\"operatingSystems\":[\"linux\"],\"resources\":{%s},\"offerings\":[%s]}\n", (n++ ? "," : "["), name, arch, res, o
    }
    END { print "]" }' "$COMP_DIR/catalog.txt"
}

# --- install --------------------------------------------------------------------
kubectl apply --server-side --force-conflicts -f "$SRC/kwok/charts/crds/" >/dev/null
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" create configmap instance-types \
  --from-literal=instance-types.json="$(catalog_json)" \
  --from-file=catalog.txt="$COMP_DIR/catalog.txt" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Values: our image; small requests; runs on the real node while sim lessons
# taint it (tolerate everything, but never on fake nodes); one replica, no
# leader-election wait; batching and log level as upstream defaults.
helm template karpenter "$SRC/kwok/charts" --namespace "$NS" --skip-crds \
  --set controller.image.repository="${IMG%:*}" \
  --set controller.image.tag="${IMG##*:}" \
  --set imagePullPolicy=IfNotPresent \
  --set replicas=1 \
  --set podDisruptionBudget.maxUnavailable=1 \
  --set-json 'tolerations=[{"operator":"Exists"}]' \
  --set-json 'affinity={"nodeAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"karpenter.sh/nodepool","operator":"DoesNotExist"},{"key":"kwok.x-k8s.io/node","operator":"DoesNotExist"},{"key":"type","operator":"DoesNotExist"}]}]}}}' \
  --set-json 'topologySpreadConstraints=[]' \
  --set-json 'controller.resources={"requests":{"cpu":"50m","memory":"128Mi"},"limits":{"memory":"512Mi"}}' \
  --set settings.batchMaxDuration=10s \
  --set settings.batchIdleDuration=1s \
  --set settings.featureGates.staticCapacity=false \
  --set settings.featureGates.capacityBuffer=false \
  --set settings.featureGates.spotToSpotConsolidation=true \
  --set settings.featureGates.nodeRepair=false \
  --set settings.featureGates.podDeletionCostManagement=false \
  --set-json 'controller.env=[{"name":"INSTANCE_TYPES_FILE_PATH","value":"/etc/kdrill/instance-types.json"},{"name":"DISABLE_LEADER_ELECTION","value":"true"}]' \
  --set-json 'extraVolumes=[{"name":"instance-types","configMap":{"name":"instance-types"}}]' \
  --set-json 'controller.extraVolumeMounts=[{"name":"instance-types","mountPath":"/etc/kdrill","readOnly":true}]' \
  2> >(grep -v 'symbolic link' >&2) | kubectl apply -f - >/dev/null
# A changed catalogue (ConfigMap) is only read at startup.
kubectl -n "$NS" rollout restart deploy/karpenter >/dev/null
kubectl -n "$NS" rollout status deploy/karpenter --timeout=180s >/dev/null || {
  kubectl -n "$NS" logs deploy/karpenter --tail=30 >&2 || true
  die "karpenter did not become ready"
}
info "karpenter ${KARPENTER_VERSION} (KWOK provider) ready in namespace $NS; $(grep -cv '^#' "$COMP_DIR/catalog.txt") instance types"
