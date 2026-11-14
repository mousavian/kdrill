# Restore KWOK's stock pod-complete stage (no delay).
if kubectl get stage pod-complete >/dev/null 2>&1; then
  kubectl patch stage pod-complete --type=json -p '[{"op":"remove","path":"/spec/delay"}]' >/dev/null 2>&1 || true
fi
info "kwok pod-complete stage restored"
