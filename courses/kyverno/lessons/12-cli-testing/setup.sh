source "$KDRILL_HOME/courses/kyverno/lib.sh"
kyv_wait_ready
lesson_nodes
cli="$(kyverno_cli)" || die "could not get the kyverno CLI (needs github.com access)"
ws="$KYV_STATE/work/kyverno-12"
rm -rf "$ws"; mkdir -p "$ws"
cp "$KDRILL_LESSON_DIR"/manifests/workspace/* "$ws/"
info "kyverno CLI:  $cli"
info "workspace:    $ws"
