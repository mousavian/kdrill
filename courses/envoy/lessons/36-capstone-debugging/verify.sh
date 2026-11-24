source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
for r in web api pay reports checkout; do
  check_eq "HTTPRoute $r: Accepted and ResolvedRefs" "True True" "$(route_cond httproute/$r Accepted) $(route_cond httproute/$r ResolvedRefs)"
done
echo "the workloads and fixed parts are unchanged"
check_eq "Deployments web/api/reports/checkout still have 1/2/1/1 replicas, pay 1 (in payments)" "1 2 1 1 1" \
  "$(jp deploy/web '{.spec.replicas}') $(jp deploy/api '{.spec.replicas}') $(jp deploy/reports '{.spec.replicas}') $(jp deploy/checkout '{.spec.replicas}') $(jp deploy/pay '{.spec.replicas}' -n payments)"
check_eq "Pod labels unchanged (reports pods: app=reports)" reports "$(jp deploy/reports '{.spec.template.metadata.labels.app}')"
check_eq "pay.lab still routes to the Service pay in namespace payments" "payments/pay" \
  "$(jp httproute/pay '{.spec.rules[0].backendRefs[0].namespace}/{.spec.rules[0].backendRefs[0].name}')"
hc="$(jp backendtrafficpolicy/checkout-health '{.spec.healthCheck.active.http.path}')"
check_eq "checkout keeps its active health check on /health (fix it, don't delete it)" /health "$hc"
site_ok() { local h="$1.lab"; [[ $1 == web ]] && h=www.lab; [[ "$(count_of "200 $1" "$(hits_out -n 2 http://edge/x -H "Host: $h")")" == 2 ]]; }
all_ok() { local s; for s in web api pay reports checkout; do site_ok $s || return 1; done; }
routes_ok=1
for r in web api pay reports checkout; do [[ "$(route_cond httproute/$r Accepted)$(route_cond httproute/$r ResolvedRefs)" == TrueTrue ]] || routes_ok=0; done
(( routes_ok )) && wait_until 25 all_ok    # after a fix: new clusters warm, health checks must pass
echo "traffic"
for s in web api pay reports checkout; do
  h="$s.lab"; [[ $s == web ]] && h=www.lab
  out="$(hits_out -n 6 http://edge/x -H "Host: $h")"
  check_eq "$h -> 6 x 200 from $s" 6 "$(count_of "200 $s" "$out")"
  [[ "$(count_of "200 $s" "$out")" == 6 ]] || why "got: $(printf '%s' "$out" | tr -s ' ' | paste -sd',' -)"
done
