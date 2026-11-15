# Strict mTLS with PeerAuthentication

## Concept

Every workload in the mesh has an identity (its ServiceAccount, as
`spiffe://cluster.local/ns/<ns>/sa/<sa>`) and a certificate for it, issued
by istiod and rotated automatically (24 h by default). Between two
sidecars, the client proxy automatically uses **mutual TLS**: both sides
present certificates, traffic is encrypted, and the server learns who is
calling (lesson 10 builds authorization on that).

What a *server* accepts is set by **PeerAuthentication**:

| mode | accepts |
|---|---|
| `PERMISSIVE` (default) | mTLS and plaintext; lets you migrate workloads into the mesh one at a time |
| `STRICT` | only mTLS; plaintext connections are reset |
| `DISABLE` | only plaintext |

Scope, from broad to narrow (the narrowest wins):

- in the root namespace `istio-system`, no selector: the whole mesh;
- in a namespace, no selector: that namespace (name it `default`);
- with `selector.matchLabels`: those workloads only;
- `portLevelMtls` (only together with a selector): per **container port**.

    apiVersion: security.istio.io/v1
    kind: PeerAuthentication
    metadata: {name: default, namespace: bank}
    spec:
      mtls: {mode: STRICT}

PeerAuthentication only governs the receiving side. The sending side is
automatic ("auto mTLS"): a sidecar uses mTLS whenever the destination has a
sidecar, unless a DestinationRule says otherwise (`trafficPolicy.tls.mode`;
lesson 14 has a bug of that kind).

## The situation

- `bank` (in the mesh): `ledger`, Service port 8000 (the API) and port
  9090 (a metrics endpoint, container port 9090).
- `shop` (in the mesh): curl client `web`.
- `legacy` (no sidecars): curl client `cron`, an old job that should no
  longer reach the ledger API. The legacy monitoring system that scrapes
  ledger's metrics port also runs outside the mesh.

Everything is PERMISSIVE, so `cron` can still call the ledger API in
plaintext.

## Your task

- Make all of namespace `bank` accept only mTLS (a namespace-wide
  PeerAuthentication; do not change the mesh-wide default).
- Exception: `ledger`'s container port 9090 stays PERMISSIVE.
- Result: `web` reaches ledger on 8000 (over mTLS) and 9090; `cron` is
  rejected on 8000 and still gets an answer on 9090.

## Useful commands

    kubectl -n legacy exec deploy/cron -c curl -- curl -sv ledger.bank:8000/get
    kubectl -n shop exec deploy/web -c curl -- curl -s ledger.bank:8000/headers
    kubectl get peerauthentication -A
    istioctl x describe pod -n bank <ledger-pod>          # effective mTLS mode per port
    istioctl proxy-config secret deploy/ledger -n bank    # the workload certificate

When you think you're done: `kdrill verify`

## On a real cluster

The usual rollout: install PERMISSIVE everywhere, move every workload into
the mesh, watch the `connection_security_policy` label on Istio's request
metrics until nothing plaintext remains, then set STRICT, first per
namespace, finally mesh-wide in `istio-system`.

## Read more

- https://istio.io/latest/docs/concepts/security/#peer-authentication
- https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/
- https://istio.io/latest/docs/reference/config/security/peer_authentication/
- https://spiffe.io/docs/latest/spiffe-about/spiffe-concepts/
