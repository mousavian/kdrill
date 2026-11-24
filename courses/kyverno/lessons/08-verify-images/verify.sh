source "$KDRILL_HOME/courses/kyverno/lib.sh"
P=verify-model-server
DIGEST=sha256:b31bfb4d0213f254d361e0079deaaebefa4f82ba7aa76ef82e90b4935ad5b105
kyv_settle

check "ClusterPolicy $P exists and is Ready" policy_ready $P
check_eq "verifyImages entry uses Enforce" Enforce "$(jp clusterpolicy/$P '{.spec.rules[*].verifyImages[*].failureAction}')"

echo "behaviour (needs Kyverno to reach ghcr.io)"
img="$(dr_get signed.yaml '{.spec.containers[0].image}')"
if [[ -z "$img" ]]; then
  _kd_fail "Signed image is admitted" "$(_short "$(kubectl create --dry-run=server -f "$KYV_PROBE_DIR/signed.yaml" 2>&1)")"
  why "Read the whole error (kubectl create --dry-run=server -f probes/signed.yaml). It ends in 'signature not found in transparency log': set keys.rekor.ignoreTlog: true. A network error means Kyverno can't reach ghcr.io."
else
  _kd_ok "Signed image is admitted"
fi
check_eq "Signed image is pinned to its digest" "ghcr.io/kyverno/test-verify-image:signed@$DIGEST" "$img"
why "imageReferences must match the image (a pattern like ghcr.io/kyverno/test-verify-image*); mutateDigest: true adds the digest (Enforce only)."
check_rejects "Unsigned image is rejected" unsigned.yaml "failed to verify image ghcr.io/kyverno/test-verify-image:unsigned"
why "In Audit mode a failed verification only shows up in reports."
check_eq "Other images (nginx:1.27) are admitted unchanged" "nginx:1.27" "$(dr_get other.yaml '{.spec.containers[0].image}')"
