# Solution

    kubectl apply -f solution/authorizationpolicies.yaml

Three policies in `bank`:

1. `allow-nothing` (`spec: {}`): applies to every workload in `bank`. Its
   existence means "ALLOW policies exist", and it matches nothing, so
   everything not allowed elsewhere is denied.
2. `ledger` (ALLOW, `app: ledger`): rule 1 lets `shop/sa/web` GET accounts;
   rule 2 lets `shop/sa/admin` do anything on accounts and admin paths.
3. `no-account-deletes` (DENY, `app: ledger`): DELETE on accounts. DENY is
   checked first, so admin's broad ALLOW rule cannot override it.

| Request | DENY match? | ALLOW match? | Result |
|---|---|---|---|
| web GET accounts | no | rule 1 | 200 |
| web POST accounts | no | no | 403 |
| admin DELETE accounts | yes | (rule 2) | 403 |
| scanner GET accounts | no | no | 403 |

`istioctl x authz check deploy/ledger -n bank` lists the three policies as
RBAC filter rules in ledger's sidecar. The 403s are produced there, with
the body `RBAC: access denied`.

Takeaways:
- Start every namespace with allow-nothing, then allow explicitly.
- DENY beats ALLOW; no ALLOW policies at all means allow.
- Principals come from mTLS, so both sides must be in the mesh.
