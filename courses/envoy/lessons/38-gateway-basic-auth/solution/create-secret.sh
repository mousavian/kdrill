#!/bin/sh
# The htpasswd Secret: one key, .htpasswd, one {SHA} line per user.
hash=$(printf '%s' 'kdrill-ops' | openssl dgst -binary -sha1 | openssl base64)
kubectl create secret generic admin-users --from-literal=.htpasswd="ops:{SHA}$hash" \
  --dry-run=client -o yaml | kubectl apply -f -
