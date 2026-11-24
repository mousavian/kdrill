source "$KDRILL_HOME/courses/envoy/lib.sh"
info "creating a test CA and certificates for shop.lab and api.lab (Secrets shop-tls, api-tls)"
pki_fresh
pki_cert shop shop.lab
pki_cert api api.lab
tls_secret shop-tls shop
tls_secret api-tls api
lab_ca_configmap
client_up
backend shop
backend api
apply_lesson manifests/edge.yaml
lab_wait shop api
gw_wait edge
