#!/usr/bin/env bash
# Lesson-authoring harness: runs a lesson's scripts the same way the kdrill
# engine does, without needing the engine. Usage:
#   hack/lesson.sh setup|verify|cleanup|reset <course>/<lesson-dir>
set -uo pipefail
phase="$1"; ref="$2"
export KDRILL_HOME="$(cd "$(dirname "$0")/.." && pwd)"
export KUBECONFIG="${KDRILL_STATE_DIR:-$HOME/.kdrill}/kubeconfig"
export KDRILL_PROFILE="${KDRILL_PROFILE:-lite}" KDRILL_NS=drill
course="${ref%%/*}"; lesson="${ref#*/}"
export KDRILL_LESSON="$course.$lesson"
export KDRILL_LESSON_DIR="$KDRILL_HOME/courses/$course/lessons/$lesson"
[[ -d "$KDRILL_LESSON_DIR" ]] || { echo "no such lesson: $KDRILL_LESSON_DIR" >&2; exit 2; }
run() { KDRILL_PHASE="$1" bash -c 'cd "$KDRILL_LESSON_DIR"; source "$KDRILL_HOME/base/lib/common.sh"; source "$1"' _ "$2"; }
do_setup() {
  kubectl taint node -l '!type,kwok.x-k8s.io/node!=fake' node-role.kubernetes.io/control-plane=:NoSchedule --overwrite >/dev/null
  kubectl create ns drill >/dev/null 2>&1; kubectl label ns drill "kdrill.dev/lesson=$KDRILL_LESSON" --overwrite >/dev/null
  kubectl config set-context --current --namespace=drill >/dev/null
  run setup "$KDRILL_LESSON_DIR/setup.sh"
}
do_cleanup() {
  [[ -f "$KDRILL_LESSON_DIR/cleanup.sh" ]] && run cleanup "$KDRILL_LESSON_DIR/cleanup.sh"
  kubectl delete ns -l kdrill.dev/lesson --ignore-not-found --timeout=120s >/dev/null
  kinds="$(kubectl api-resources --namespaced=false --verbs=delete -o name | grep -v '^namespaces$' | paste -sd, -)"
  kubectl delete "$kinds" -l kdrill.dev/lesson --ignore-not-found >/dev/null 2>&1
  echo "  cleaned up"
}
case "$phase" in
  setup) do_setup ;;
  verify) run verify "$KDRILL_LESSON_DIR/verify.sh" ;;
  cleanup) do_cleanup ;;
  reset) do_cleanup; do_setup ;;
  *) echo "unknown phase $phase" >&2; exit 2 ;;
esac
