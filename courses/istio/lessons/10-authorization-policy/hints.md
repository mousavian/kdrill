Today every client gets 200:

    for c in web admin scanner; do kubectl -n shop exec deploy/$c -c curl -- curl -s -o /dev/null -w "$c %{http_code}\n" ledger.bank:8000/anything/accounts/42; done

Start with deny-by-default: an AuthorizationPolicy in `bank` with
`spec: {}`. Then everything is 403, and you add what is allowed.
---
Identities look like `cluster.local/ns/<namespace>/sa/<serviceaccount>`.
An ALLOW policy for `app: ledger` with two rules:

- `from: [{source: {principals: [cluster.local/ns/shop/sa/web]}}]`,
  `to: [{operation: {methods: [GET], paths: [/anything/accounts/*]}}]`
- `from` admin, `to` paths `/anything/accounts/*` and `/anything/admin/*`.

Then a separate policy with `action: DENY` for DELETE on accounts.
---
    kubectl apply -f solution/authorizationpolicies.yaml
    istioctl x authz check deploy/ledger -n bank
