# Authorization: deny by default, allow by identity, path and method

## Concept

mTLS tells the server *who* is calling (the SPIFFE identity in the client
certificate). **AuthorizationPolicy** decides *what* they may do. The
server's sidecar enforces it on every request, before the application sees
it.

    apiVersion: security.istio.io/v1
    kind: AuthorizationPolicy
    metadata: {name: ledger, namespace: bank}
    spec:
      selector:                       # which workloads (none = whole namespace)
        matchLabels: {app: ledger}
      action: ALLOW                   # ALLOW (default) | DENY | CUSTOM | AUDIT
      rules:                          # a request matching ANY rule matches the policy
      - from:                         # who: principals, namespaces, ipBlocks, requestPrincipals (JWT)
        - source:
            principals: [cluster.local/ns/shop/sa/web]
        to:                           # what: methods, paths, ports, hosts
        - operation:
            methods: [GET]
            paths: [/anything/accounts/*]
        when:                         # extra conditions: headers, JWT claims, ...
        - key: request.headers[x-team]
          values: [payments]

Inside a rule, `from`, `to` and `when` are ANDed; list entries are ORed.
Negative forms exist too: `notPrincipals`, `notPaths`, `notMethods`, ...

**Evaluation** for a request to a workload:

1. If any **DENY** policy matches, deny.
2. If there are **no ALLOW** policies for the workload, allow.
3. If any ALLOW policy matches, allow; otherwise deny.

Rule 2 is why the first policy is usually **allow-nothing**: an ALLOW
policy with no rules (`spec: {}`). It applies to every workload of the
namespace and matches nothing, so from then on only what other ALLOW
policies list gets through. Denied HTTP requests get `403` with body
`RBAC: access denied`.

`principals` work only for mTLS traffic (that is where the identity comes
from), so authorization by identity requires both sides in the mesh.
Methods and paths need HTTP (lesson 02).

## The situation

`bank/ledger` (go-httpbin: `/anything/<path>` accepts any method and path)
holds account data under `/anything/accounts/...` and an admin API under
`/anything/admin/...`. In `shop` (in the mesh) run three curl clients with
their own ServiceAccounts: `web`, `admin` and `scanner`. There are no
policies, so all three can do anything.

## Your task

AuthorizationPolicies in namespace `bank` so that:

- everything in `bank` is denied by default (an allow-nothing policy);
- `shop/web` may `GET /anything/accounts/*`, nothing else;
- `shop/admin` may use any method on `/anything/accounts/*` and
  `/anything/admin/*`;
- nobody, not even admin, may `DELETE` `/anything/accounts/*`;
- any other caller (e.g. `scanner`) gets 403.

## Useful commands

    kubectl -n shop exec deploy/admin -c curl -- curl -s -X DELETE -w '\n%{http_code}\n' ledger.bank:8000/anything/accounts/42
    kubectl get authorizationpolicy -A
    istioctl x authz check deploy/ledger -n bank       # policies loaded in ledger's sidecar
    kubectl -n bank logs deploy/ledger -c istio-proxy --tail=5

When you think you're done: `kdrill verify`

## On a real cluster

Start with an `action: AUDIT` policy or a dry-run annotation
(`istio.io/dry-run: "true"`) to see what would be denied before enforcing.
Keep allow-nothing per namespace rather than mesh-wide at first, and allow
health checks and metrics scrapes explicitly.

## Read more

- https://istio.io/latest/docs/concepts/security/#authorization
- https://istio.io/latest/docs/reference/config/security/authorization-policy/
- https://istio.io/latest/docs/ops/best-practices/security/#use-default-deny-patterns
- https://istio.io/latest/docs/tasks/security/authorization/authz-http/
