source "$KDRILL_HOME/courses/inference/lib.sh"
client_up
# The namespace has room for the client pod and four model pods: five pods, no more.
kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: ResourceQuota
metadata: {name: capacity}
spec:
  hard: {pods: "5"}
YAML
apply_lesson manifests/llm.yaml
lab_wait llm
# a new model version is rolled out: v1 -> v2
kubectl set env deploy/llm MODEL_VERSION=v2 >/dev/null
info "version v2 was just rolled out: kubectl rollout status deploy/llm"
