source "$KDRILL_HOME/courses/kyverno/lib.sh"
P=gpu-product-required
WS="$KYV_STATE/work/kyverno-12"
cli="$(kyverno_cli 2>/dev/null)"

echo "workspace: $WS"
check "kyverno CLI available ($KYV_VERSION)" test -x "$cli"
check "Workspace has policy.yaml, resources.yaml, kyverno-test.yaml" test -f "$WS/policy.yaml" -a -f "$WS/resources.yaml" -a -f "$WS/kyverno-test.yaml"
why "kdrill reset re-creates the workspace (and overwrites your edits)."

out="$(cd "$WS" 2>/dev/null && "$cli" test . 2>&1)"; rc=$?
check_eq "kyverno test passes in your workspace" 0 "$rc"
why "cd $WS && $cli test .   $(printf '%s' "$out" | grep -E 'Fail|Error' | head -3 | tr -s ' ' | tr '\n' ' ')"
check "Your suite tests resource gpu-sidecar-missing (GPU in the 2nd container)" bash -c 'grep -q "name: gpu-sidecar-missing" "$1/resources.yaml" && printf "%s" "$2" | grep "gpu-sidecar-missing" | grep -q "Pass"' _ "$WS" "$out"
why "Add the Pod to resources.yaml and a results entry for it to kyverno-test.yaml."
exp="$(awk '/^- /{blk=""} {blk=blk $0 "\n"} /result:/{ if (blk ~ /gpu-sidecar-missing/) print $NF }' "$WS/kyverno-test.yaml" 2>/dev/null | tr -d '}' | head -1)"
check_eq "...and expects it to fail the policy" fail "$exp"
why "A GPU Pod without nvidia.com/gpu.product must fail, whichever container asks for the GPU."

tmp="$(mktemp -d "${TMPDIR:-/tmp}/kdrill-kyv.XXXXXX")"
cp "$KDRILL_LESSON_DIR"/tests/* "$tmp/" && cp "$WS/policy.yaml" "$tmp/policy.yaml" 2>/dev/null
ref="$(cd "$tmp" && "$cli" test . 2>&1)"; rc=$?
rm -rf "$tmp"
check_eq "kdrill's reference suite (tests/) passes against your policy.yaml" 0 "$rc"
why "$(printf '%s' "$ref" | grep -E '│ Fail' | awk -F'│' '{print $5 $7}' | tr -s ' ' | head -3 | tr '\n' ';')"

echo "cluster"
kyv_settle
check "ClusterPolicy $P is applied and Ready" policy_ready $P
why "kubectl apply -f $WS/policy.yaml"
check_rejects "ml: a Pod with the GPU in its 2nd container and no GPU type is rejected" gpu-sidecar-missing.yaml "GPU Pods must set nodeSelector nvidia.com/gpu.product"
check_admits "ml: a GPU Pod with nvidia.com/gpu.product is admitted" gpu-ok.yaml
