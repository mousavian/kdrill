source "$KDRILL_HOME/courses/istio/lib.sh"
NS=mall
A=http://api:8000
rollouts $NS waypoint
settle 2
await_code 10 403 $NS bot $A/get

echo "ambient enrolment"
check_eq "Namespace mall has istio.io/dataplane-mode=ambient" ambient "$(jp ns/$NS '{.metadata.labels.istio\.io/dataplane-mode}')"
check_eq "No Pod in mall has a sidecar (or an injection label)" "none|" "$(sidecar_state $NS 'app in (web,bot,api)')|$(jp ns/$NS '{.metadata.labels.istio-injection}')"
why "Ambient replaces sidecars; don't combine it with istio-injection=enabled in this lesson."
red="$(kubectl -n $NS get pods -l 'app in (web,bot,api)' -o jsonpath='{range .items[*]}{.metadata.annotations.ambient\.istio\.io/redirection}{"\n"}{end}' 2>/dev/null | sort -u | paste -sd' ' -)"
check_eq "The istio-cni agent redirected every app Pod to ztunnel (ambient.istio.io/redirection)" enabled "$red"

echo "waypoint"
check_eq "Gateway waypoint (class istio-waypoint) is Programmed" "istio-waypoint True" \
  "$(jp gateway.gateway.networking.k8s.io/waypoint '{.spec.gatewayClassName} {.status.conditions[?(@.type=="Programmed")].status}' -n $NS)"
why "istioctl waypoint apply -n mall, or a Gateway with gatewayClassName istio-waypoint and an HBONE listener on 15008."
uw="$(jp ns/$NS '{.metadata.labels.istio\.io/use-waypoint}')$(jp svc/api '{.metadata.labels.istio\.io/use-waypoint}' -n $NS)"
check_eq "Traffic to api is sent through the waypoint (istio.io/use-waypoint on the namespace or Service)" waypoint "$uw"
h="$(http_headers $NS web $A/get)"
check "web -> api is handled by an Envoy (x-envoy-upstream-service-time: the waypoint)" grep -qi '^x-envoy-upstream-service-time:' <<<"$h"
why "ztunnel alone only does L4. Without a waypoint in the path there is no HTTP processing."

echo "policy"
check_eq "web GET  api/get  -> 200" 200 "$(http_code $NS web $A/get)"
check_eq "web POST api/post -> 403" 403 "$(http_code $NS web $A/post -X POST)"
check_eq "bot GET  api/get  -> 403" 403 "$(http_code $NS bot $A/get)"
check "The 403 is an L7 denial from the waypoint (RBAC: access denied)" grep -q 'RBAC: access denied' <<<"$(http_body $NS bot $A/get)"
why "Attach the policy to the Service with targetRefs: [{kind: Service, group: \"\", name: api}] so the waypoint enforces it."
