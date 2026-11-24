source "$KDRILL_HOME/courses/kyverno/lib.sh"
VP=require-memory-limits
VAP="ValidatingAdmissionPolicy 'vpol-$VP'"
MSG="every container needs a memory limit"
_generated() { [[ "$(jp validatingpolicy/$VP '{.status.generated}')" == true ]]; }
probe_ns kyv-probe-other
kyv_settle
wait_b 20 _generated

check_eq "ClusterPolicy require-limits is gone (migration finished)" "" "$(jp clusterpolicy/require-limits '{.metadata.name}')"
check_eq "ValidatingPolicy $VP (policies.kyverno.io/v1) exists and is ready" true "$(jp validatingpolicy/$VP '{.status.conditionStatus.ready}')"
check_eq "It denies (validationActions: [Deny])" Deny "$(jp validatingpolicy/$VP '{.spec.validationActions[*]}')"
check_eq "Kyverno generated a ValidatingAdmissionPolicy from it" "true vpol-$VP" \
  "$(jp validatingpolicy/$VP '{.status.generated}') $(jp validatingadmissionpolicy/vpol-$VP '{.metadata.name}')"
why "spec.autogen.validatingAdmissionPolicy.enabled: true. The VP's status says why it was skipped: $(jp validatingpolicy/$VP '{.status.conditionStatus.message}')"

echo "behaviour in ml-serving (rejections must come from the native $VAP)"
check_rejects "Pod without a memory limit: rejected, message names the container" pod-no-limit.yaml "$MSG: model" ml-serving
check_rejects "  ...and the rejection comes from the ValidatingAdmissionPolicy" pod-no-limit.yaml "$VAP" ml-serving
check_rejects "Pod whose initContainer lacks a memory limit: rejected, names fetch-model" pod-init-no-limit.yaml "$MSG: fetch-model" ml-serving
check_rejects "Deployment whose container lacks a memory limit: rejected by the VAP" deployment-no-limit.yaml "$VAP" ml-serving
why "Match deployments in matchConstraints too, and read the Pod spec from object.spec.template.spec for them."
check_admits "Compliant Pod: admitted" pod-good.yaml ml-serving
check_admits "Copy of the compliant ranker Deployment: admitted" deployment-good.yaml ml-serving
check_admits "Another namespace: the Pod without limits is admitted (scope unchanged)" pod-no-limit.yaml kyv-probe-other
check_eq "Deployment ranker: 2 ready" 2 "$(jp deploy/ranker '{.status.readyReplicas}' -n ml-serving)"
