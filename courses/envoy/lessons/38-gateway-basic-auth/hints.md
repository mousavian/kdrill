Authentication is Envoy Gateway's SecurityPolicy, attached to a route like
the policies in lessons 28 and 31:

    kubectl explain securitypolicy.spec.basicAuth
    kubectl get httproute

The user list is a Secret with one key, `.htpasswd`, in Apache htpasswd
format.
---
Envoy accepts SHA-1 password hashes (`{SHA}` prefix + base64 of the binary
digest):

    hash=$(printf '%s' 'kdrill-ops' | openssl dgst -binary -sha1 | openssl base64)
    kubectl create secret generic admin-users --from-literal=.htpasswd="ops:{SHA}$hash"

(or `htpasswd -nbs ops kdrill-ops` if you have it). Then a SecurityPolicy
with `targetRefs: [{group: gateway.networking.k8s.io, kind: HTTPRoute, name: admin}]`
and `basicAuth: {users: {name: admin-users}, forwardUsernameHeader: x-user}`.
---
From the lesson directory:

    sh solution/create-secret.sh
    kubectl apply -f solution/securitypolicy.yaml
