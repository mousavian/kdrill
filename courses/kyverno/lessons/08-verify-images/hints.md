Try both images and read what Kyverno says:

    kubectl create --dry-run=server -f probes/unsigned.yaml
    kubectl create --dry-run=server -f probes/signed.yaml -o jsonpath='{.spec.containers[0].image}'

Nothing happens to either. Is the rule even matching the image?
`imageReferences` are patterns matched against the full image reference,
tag included.
---
Three things:
- `imageReferences: ["ghcr.io/kyverno/test-verify-image*"]`
- `failureAction: Enforce` (on the verifyImages entry) and `mutateDigest: true`
  (Kyverno only allows digest mutation with Enforce)
- the signature was not uploaded to the public transparency log, so
  verification still fails. The error is long and starts with a confusing
  "comparing public key PEMs" (the image also carries a signature by another
  key); read it to the end: `signature not found in transparency log`. Add
  `rekor: {ignoreTlog: true, url: https://rekor.sigstore.dev}` (and
  `ctlog: {ignoreSCT: true}`) next to `publicKeys`.
---
    kubectl apply -f solution/policy.yaml      # from the lesson directory

The signed image comes back as `...:signed@sha256:b31b...`, so the Pod is
pinned to exactly the bytes that were verified.
