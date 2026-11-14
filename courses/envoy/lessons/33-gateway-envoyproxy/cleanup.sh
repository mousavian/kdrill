# A Gateway-level EnvoyProxy without mergeType gives the Gateway a LoadBalancer
# Service. k3s marks such Services with a load-balancer-cleanup finalizer that
# nothing in this lab removes, which would hold up namespace deletion for minutes.
set +e
kubectl -n lab delete gateway --all --wait=false >/dev/null 2>&1
for s in $(kubectl -n lab get svc -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{" "}{end}' 2>/dev/null); do
  kubectl -n lab patch svc "$s" --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1
done
exit 0
