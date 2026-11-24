source "$KDRILL_HOME/courses/envoy/lib.sh"
info "creating a test CA and certificates for shop.lab and api.lab"
pki_fresh
pki_cert shop shop.lab
pki_cert api api.lab
file_secret envoy-certs shop.crt shop.key api.crt api.key
lab_ca_configmap
client_up
backend shop
backend api
apply_lesson manifests/envoy-config.yaml
envoy_up
lab_wait shop api envoy
