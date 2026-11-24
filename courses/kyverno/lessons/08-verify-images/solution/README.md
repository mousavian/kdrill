# Solution

    kubectl apply -f solution/policy.yaml      # from the lesson directory

Four changes:

1. `imageReferences: ["ghcr.io/kyverno/test-verify-image*"]`. The value is
   a pattern matched against the whole reference including the tag, so the
   bare repository name matched nothing and the rule never ran.
2. `failureAction: Enforce` on the verifyImages entry, and `mutateDigest:
   true` (Kyverno refuses digest mutation in Audit mode, hence the `false`).
3. `rekor.ignoreTlog: true` (and `ctlog.ignoreSCT: true`). By default
   Kyverno also requires the signature to be recorded in the public Rekor
   transparency log. Key-pair signatures made with `--tlog-upload=false`
   (common for private CI) aren't there, so verification fails even with
   the right key.

What you get:
- Unsigned (or signed with another key): rejected, `failed to verify image ...`.
- Signed: admitted, and the image becomes `...:signed@sha256:b31b...`
  (`mutateDigest`). Tags can be moved; a digest can't, so the Pod runs
  exactly the bytes that were checked. `verifyDigest` (default true) then
  also rejects later requests whose digest doesn't match.
- Other images: not matched, untouched.

In production you'd usually sign **keyless** (Sigstore Fulcio + OIDC
identity of the CI job) and verify with `attestors[].entries[].keyless`
(`subject`, `issuer`), keep the transparency log on, and also verify
**attestations** (SBOMs, vulnerability scans, SLSA provenance) with
`attestations:` conditions. Kyverno 1.19's CEL-based ImageValidatingPolicy
does the same with CEL expressions.

Takeaways:
- Signature checks run on the admission path and call the registry: set
  `webhookTimeoutSeconds`, and make sure Kyverno can reach your registries.
- Pin by digest after verifying.
