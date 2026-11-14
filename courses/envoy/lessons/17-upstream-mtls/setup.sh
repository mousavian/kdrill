source "$KDRILL_HOME/courses/envoy/lib.sh"
info "creating a test CA, a server certificate for payments and a client certificate for Envoy"
pki_fresh
pki_cert payments payments payments payments.lab.svc payments.lab.svc.cluster.local
pki_cert client envoy-client
tls_secret payments-tls payments --ca
file_secret envoy-certs client.crt client.key ca.crt
lab_ca_configmap
client_up
backend payments --tls payments-tls --mtls
apply_lesson manifests/envoy-config.yaml
envoy_up
lab_wait payments envoy
