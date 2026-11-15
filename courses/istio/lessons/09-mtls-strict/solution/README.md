# Solution

    kubectl apply -f solution/peerauthentication.yaml

- `PeerAuthentication default` in `bank` (no selector) sets STRICT for the
  whole namespace.
- `PeerAuthentication ledger-metrics` selects `app: ledger`, keeps STRICT
  and overrides container port 9090 to PERMISSIVE. The workload-specific
  policy wins over the namespace one; ports not listed inherit its `mtls`.

Results:

- `cron -> ledger:8000`: ledger's sidecar only offers a TLS filter chain on
  that port, so the plaintext HTTP request is reset; curl reports `000` /
  "Connection reset by peer".
- `cron -> ledger:9090`: PERMISSIVE, plaintext accepted.
- `web -> ledger`: unchanged; it was already mTLS (auto mTLS), and
  ledger's sidecar puts web's identity in `X-Forwarded-Client-Cert`.

Takeaways:
- PeerAuthentication controls what the server accepts; the client side is
  automatic.
- Narrowest scope wins: mesh < namespace < workload < port.
- Prove STRICT with a client outside the mesh, not just with one inside.
