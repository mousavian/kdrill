source "$KDRILL_HOME/courses/istio/lib.sh"
NS=store
settle 2

echo "services"
check_eq "catalog still exposes port 8000 -> 8080" "8000 8080" "$(jp svc/catalog '{.spec.ports[0].port} {.spec.ports[0].targetPort}' -n $NS)"
check_eq "reviews still exposes port 8000 -> 8080" "8000 8080" "$(jp svc/reviews '{.spec.ports[0].port} {.spec.ports[0].targetPort}' -n $NS)"
check_eq "VirtualService catalog is unchanged (sets x-route: catalog-mesh)" catalog-mesh \
  "$(jp virtualservice/catalog '{.spec.http[0].headers.response.set.x-route}' -n $NS)"
why "The VirtualService is fine; the problem is how Istio classifies the Service port. kdrill reset restores it."

echo "frontend's sidecar"
routes="$(proxy_admin $NS frontend 'config_dump?resource=dynamic_route_configs')"
check "frontend's Envoy has an HTTP route for catalog.store.svc.cluster.local:8000" grep -q '"catalog.store.svc.cluster.local:8000"' <<<"$routes"
check "frontend's Envoy has an HTTP route for reviews.store.svc.cluster.local:8000" grep -q '"reviews.store.svc.cluster.local:8000"' <<<"$routes"
why "istioctl proxy-config routes deploy/frontend -n store. A TCP port gets a TCP proxy listener and no HTTP route at all."

echo "traffic (frontend -> service)"
h="$(http_headers $NS frontend http://catalog:8000/get)"
check "catalog answers 200" grep -q '^HTTP/1.1 200' <<<"$h"
check "catalog responses carry x-route: catalog-mesh (the VirtualService applies)" grep -qi '^x-route: catalog-mesh' <<<"$h"
why "VirtualService http routes only apply to traffic Istio handles as HTTP."
h="$(http_headers $NS frontend http://reviews:8000/get)"
check "reviews answers 200" grep -q '^HTTP/1.1 200' <<<"$h"
check "reviews responses went through Envoy's HTTP router (x-envoy-upstream-service-time)" grep -qi '^x-envoy-upstream-service-time:' <<<"$h"
why "appProtocol wins over the port name. appProtocol: tcp means opaque TCP."
