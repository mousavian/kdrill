# Solution

From the lesson directory:

    kubectl apply -f solution/policy.yaml
    kubectl apply -f solution/web.yaml

The policy changes:

- `validate.failureAction: Enforce`: a failing request is now rejected
  instead of only being reported.
- `message`: what the user sees in the rejection.
- `team: "?*"`: at least one character. `"*"` accepts any value, including an
  empty string, so `team: ""` used to pass.

The Deployment needs `team: shop` in its Pod template. Its running Pods were
created before the policy enforced anything, and admission never re-checks
existing objects, so they keep running. But the next rollout or re-scheduled
Pod would have been rejected. Kyverno even checks the Deployment itself
(an "autogen" rule, lesson 03), so the broken template is caught at
`kubectl apply` time.

Takeaways:
- Kyverno is an admission webhook: it only sees requests (create, update,
  ...), never what is already stored.
- Roll out new rules in Audit, read the reports, then switch to Enforce.
- `?*` is "required and non-empty", `*` is only "present".
