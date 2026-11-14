source "$KDRILL_HOME/courses/envoy/lib.sh"
info "creating a test CA and certificates for a.lab and b.lab (they stay in the backends)"
pki_fresh
pki_cert a a.lab
pki_cert b b.lab
tls_secret site-a-tls a
tls_secret site-b-tls b
lab_ca_configmap
client_up
backend site-a --tls site-a-tls
backend site-b --tls site-b-tls
apply_lesson manifests/envoy-config.yaml
envoy_up
lab_wait site-a site-b envoy
