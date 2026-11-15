Try both clients first: the one in the mesh and the plaintext one.

    kubectl -n shop exec deploy/web -c curl -- curl -s ledger.bank:8000/headers
    kubectl -n legacy exec deploy/cron -c curl -- curl -s -o /dev/null -w '%{http_code}\n' ledger.bank:8000/get
    kubectl explain peerauthentication.spec
---
Two PeerAuthentications in `bank`:

- `default`, no selector, `mtls: {mode: STRICT}`: the whole namespace.
- `ledger-metrics`, `selector: {matchLabels: {app: ledger}}`,
  `mtls: {mode: STRICT}`, `portLevelMtls: {9090: {mode: PERMISSIVE}}`.

`portLevelMtls` needs a selector and uses the container (target) port.
---
    kubectl apply -f solution/peerauthentication.yaml
    istioctl x describe pod -n bank $(kubectl -n bank get pod -l app=ledger -o name | head -1 | cut -d/ -f2)
