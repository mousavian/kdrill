source "$KDRILL_HOME/courses/istio/lib.sh"
NS=shop

echo "injection"
check_eq "Namespace shop has istio-injection=enabled" enabled "$(jp ns/$NS '{.metadata.labels.istio-injection}')"
why "kubectl label namespace shop istio-injection=enabled"
for d in web api client; do
  check_eq "Every $d Pod has an istio-proxy sidecar and is Ready" all "$(sidecar_state $NS app=$d)"
done
why "Injection happens when a Pod is created. Existing Pods keep running without a sidecar: kubectl -n shop rollout restart deploy"

echo "opt-out"
optout="$(jp deploy/batch '{.spec.template.metadata.labels.sidecar\.istio\.io/inject}{.spec.template.metadata.annotations.sidecar\.istio\.io/inject}' -n $NS)"
check_eq "batch's Pod template opts out (sidecar.istio.io/inject: \"false\")" false "$optout"
why "Set it as a label (preferred) or annotation on spec.template.metadata, not on the Deployment itself."
check_eq "batch Pods run without a sidecar and are Ready" none "$(sidecar_state $NS app=batch)"
check_eq "batch: 1 replica ready" 1 "$(jp deploy/batch '{.status.readyReplicas}' -n $NS)"

echo "traffic"
hdrs="$(http_body $NS client http://api:8000/headers)"
check "client -> api answers through the mesh" test -n "$hdrs"
check "api sees client's mTLS identity spiffe://cluster.local/ns/shop/sa/client" \
  grep -q 'URI=spiffe://cluster.local/ns/shop/sa/client' <<<"$hdrs"
why "The server sidecar adds X-Forwarded-Client-Cert only when the request arrived over Istio mTLS from a client sidecar."
check_eq "batch (no sidecar) -> web still works: 200 (PERMISSIVE accepts plaintext)" 200 "$(http_code $NS batch http://web:8000/get)"
