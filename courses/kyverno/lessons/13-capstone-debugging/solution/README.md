# Solution

From the lesson directory:

    kubectl apply -f solution/policies.yaml
    kubectl -n payments rollout restart deploy fraud-model

(If you created the policies another way, also remove the annotation:
`kubectl annotate clusterpolicy require-run-as-nonroot pod-policies.kyverno.io/autogen-controllers-`.)

| Policy | Symptom | Bug | Fix |
|---|---|---|---|
| require-owner-label | Pod without owner admitted (only the report says fail) | `failureAction: Audit` | `Enforce` (FIX 1) |
| restrict-registries | docker.io admitted silently | `namespaceSelector` on `environment: prod`; namespaces have `env` | `env: prod` (FIX 2) |
| require-run-as-nonroot | Job/CronJob admitted | `autogen-controllers: Deployment` | remove the annotation (FIX 3) |
| require-run-as-nonroot | Pod without securityContext admitted | `=(securityContext): =(runAsNonRoot)` = "if present" | plain keys = required (FIX 4) |
| gpu-tier | GPU Pod labelled but no toleration; fraud-model Pending | the toleration rule runs before the label rule | swap the rules (FIX 5) |

Notes:
- A wrong label key in a selector is the most dangerous bug: no error, no
  warning, no report entry. Probing from a namespace that *should* match is
  the only way to see it.
- With `=( )` anchors at every level, a pattern accepts objects that simply
  omit the field. Use anchors only for genuinely optional parts.
- Mutate rules within a policy are applied in order, each seeing the
  previous rule's output; across policies there's no ordering you should
  rely on, so put dependent rules in one policy.
- After a mutate fix, existing Pods keep their old spec: restart them.

Takeaways: test policies by behaviour (dry-runs, `kyverno test`), in the
namespaces they're meant for, including controller kinds; read reports;
fix the policy, not the symptom.
