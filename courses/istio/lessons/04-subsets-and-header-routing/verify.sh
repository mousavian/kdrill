source "$KDRILL_HOME/courses/istio/lib.sh"
NS=shop
U=http://catalog:8000/hostname
settle 2

echo "config"
check_eq "DestinationRule catalog: subset v1 -> version=v1, v2 -> version=v2" "v1=v1 v2=v2" \
  "$(kubectl -n $NS get destinationrule catalog -o jsonpath='{range .spec.subsets[*]}{.name}={.labels.version}{" "}{end}' 2>/dev/null | sed 's/ $//')"
why "A subset is a label selector over the Service's Pods: kubectl -n shop get pods --show-labels"
check_eq "VirtualService catalog exists for host catalog" catalog "$(jp virtualservice/catalog '{.spec.hosts[0]}' -n $NS)"

echo "traffic (web -> catalog)"
check_eq "20 requests without the header all go to catalog-v1" "catalog-v1:20" "$(backends $NS web $U 20)"
check_eq "10 requests with x-beta: true all go to catalog-v2" "catalog-v2:10" "$(backends $NS web $U 10 -H 'x-beta: true')"
why "Routes are evaluated top to bottom; the first match wins. Put the header match before the catch-all route."
check_eq "10 requests with x-beta: false go to catalog-v1" "catalog-v1:10" "$(backends $NS web $U 10 -H 'x-beta: false')"
why "Match the value exactly (exact: \"true\"), not just the presence of the header."
