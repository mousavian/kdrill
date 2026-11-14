# Verify image signatures (supply chain)

## Concept

Validating an image *name* (lesson 02) says nothing about its contents.
Signatures do. CI signs the image digest with **cosign**, and the signature
is stored in the registry next to the image. A `verifyImages` rule makes
Kyverno check that signature at admission:

    verifyImages:
    - imageReferences: ["registry.acme.io/models/*"]
      failureAction: Enforce
      attestors:
      - entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              ...

For each container image matching `imageReferences` (patterns over the full
reference, tag included), Kyverno resolves the tag to a digest, fetches the
signatures from the registry and checks them against the attestors:

- **keys**: a public key (cosign key pair); or **keyless**: a certificate
  identity (`subject`, `issuer`) from Sigstore's Fulcio CA, usually the CI
  job's OIDC identity.
- By default the signature must also be in the public **Rekor**
  transparency log. Signatures created without uploading there need
  `rekor.ignoreTlog: true`.
- `mutateDigest: true` (default) rewrites `image:tag` to `image:tag@sha256:...`,
  so the node pulls exactly what was verified even if someone moves the tag
  later.
- `attestations` go further: verify signed SBOMs, vulnerability scan results
  or SLSA provenance, with conditions on their content.

The admission controller talks to the registry during the request, so set
`webhookTimeoutSeconds` generously, give Kyverno credentials for private
registries (`imageRegistryCredentials`), and make sure it can reach them.
Results are cached.

## The situation

The team's model-server images (`ghcr.io/kyverno/test-verify-image`, a public
test image signed by the Kyverno project) are signed by CI with the key in
`manifests/cosign.pub`, without uploading to Rekor. ClusterPolicy
`verify-model-server` was meant to enforce this, but both the `:unsigned`
and the `:signed` image get in untouched.

## Your task

Fix `verify-model-server` (keep the name) so that:

- `ghcr.io/kyverno/test-verify-image:unsigned` is rejected
  (`failed to verify image ...`), with the verifyImages entry on `Enforce`;
- `ghcr.io/kyverno/test-verify-image:signed` is admitted and its image is
  rewritten to `ghcr.io/kyverno/test-verify-image:signed@sha256:b31bfb4d...`
  (the verified digest);
- other images (`nginx:1.27`) are admitted unchanged.

verify dry-runs the Pods in `probes/`. **This lesson needs internet access**
from the cluster to ghcr.io.

## Useful commands

    kubectl create --dry-run=server -f probes/signed.yaml -o jsonpath='{.spec.containers[0].image}'
    kubectl create --dry-run=server -f probes/unsigned.yaml
    kubectl explain clusterpolicy.spec.rules.verifyImages
    kubectl explain clusterpolicy.spec.rules.verifyImages.attestors.entries.keys.rekor
    kubectl -n kyverno logs deploy/kyverno-admission-controller --tail=20

When you think you're done: `kdrill verify`

## On a real cluster

The Pods here never pull anything (fake nodes), but Kyverno really fetches
the signature from ghcr.io. In production, sign keyless from CI, keep the
transparency log on, and verify attestations too. Kyverno's admission
controller needs egress to every registry it verifies.

## Read more

- https://kyverno.io/docs/policy-types/cluster-policy/verify-images/overview/
- https://kyverno.io/docs/policy-types/cluster-policy/verify-images/sigstore/
- https://kyverno.io/docs/policy-types/image-validating-policy/
- https://docs.sigstore.dev/cosign/signing/signing_with_containers/
