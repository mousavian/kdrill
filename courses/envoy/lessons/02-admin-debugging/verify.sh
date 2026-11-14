source "$KDRILL_HOME/courses/envoy/lib.sh"
check_envoy_basics

echo "the backends are unchanged (fix Envoy, not the apps)"
check_eq "Services shop, catalog, api still listen on port 80" "80 80 80" \
  "$(jp svc/shop '{.spec.ports[0].port}') $(jp svc/catalog '{.spec.ports[0].port}') $(jp svc/api '{.spec.ports[0].port}')"

echo "behaviour (10 requests per site from the client pod, Host header set)"
for site in shop catalog api; do
  out="$(hits_out -n 10 http://envoy:10000/products/42 -H "Host: $site.lab")"
  check_eq "Host $site.lab, GET /products/42: 10 x 200 from $site" 10 "$(count_of "200 $site" "$out")"
  case $site in
    shop) why "admin /clusters: does the host shop:8080 exist? Is anything listening there? (stat cluster.shop.upstream_cx_connect_fail)" ;;
    catalog) why "admin /clusters shows no host for catalog: what name does it resolve? (stat cluster.catalog.membership_total)" ;;
    api) why "404 from Envoy itself (no route matched, stat http.ingress.no_route): read the route in admin /config_dump?resource=static_route_configs" ;;
  esac
done
check_eq "Host api.lab, GET /: 200 from api" 200 "$(http_code http://envoy:10000/ -H 'Host: api.lab')"
check_eq "An unknown host (nope.lab) still gets 404 from Envoy" 404 "$(http_code http://envoy:10000/ -H 'Host: nope.lab')"
why "Keep the three virtual hosts specific; don't add a catch-all domain \"*\"."
