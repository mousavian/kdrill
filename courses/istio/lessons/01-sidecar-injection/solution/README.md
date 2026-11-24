# Solution

    kubectl label namespace shop istio-injection=enabled
    kubectl apply -f solution/batch.yaml          # from the lesson directory
    kubectl -n shop rollout restart deploy web api client
    kubectl -n shop get pods

`solution/batch.yaml` adds the label `sidecar.istio.io/inject: "false"` to
the Pod template of `batch`. Applying it rolls `batch` too; its new Pod is
created in an injected namespace but skipped by the webhook.

What changed in an injected Pod (`kubectl -n shop get pod -l app=api -o yaml`):

- `initContainers`: `istio-validation` (checks the CNI agent set up the
  traffic redirection) and `istio-proxy` with `restartPolicy: Always`
  (native sidecar: pilot-agent + Envoy).
- annotations such as `sidecar.istio.io/status`, and volumes for the
  workload certificate and istiod's root CA.

`client -> api` now goes client app -> client sidecar -> (mTLS) -> api
sidecar -> api app. The api sidecar puts the verified client identity in
`X-Forwarded-Client-Cert: ...;URI=spiffe://cluster.local/ns/shop/sa/client`.
The identity comes from the Pod's ServiceAccount, which is why every
workload in this course has its own.

`batch -> web` still works because servers default to PERMISSIVE mTLS:
they accept both mTLS and plaintext. Lesson 09 turns that off.

Takeaways:
- Injection is a Pod-creation-time webhook: label, then restart.
- Opt out per Pod with `sidecar.istio.io/inject: "false"` in the template.
- Identity = ServiceAccount; mTLS between sidecars is automatic.
