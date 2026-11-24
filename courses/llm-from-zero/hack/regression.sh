#!/usr/bin/env bash
# Regression for llm-from-zero. From an EMPTY workspace, for every lesson in order:
#   start -> verify must FAIL on the untouched starter -> apply the reference
#   solution -> verify must PASS. Prints the time of each passing verify.
#
#   hack/regression.sh [first-lesson-prefix [last-lesson-prefix]]
#
# Uses a temporary KDRILL_WORK / KDRILL_STATE_DIR / KDRILL_CACHE (never your own),
# no cluster. Needs docker and `make build` done (bin/kdrill).
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
home="$(cd "$here/../.." && pwd)"
KD="$home/bin/kdrill"
[[ -x "$KD" ]] || { echo "build first: make -C $home build" >&2; exit 2; }
tmp="${KDRILL_REG_TMP:-$(mktemp -d "${TMPDIR:-/tmp}/llm-reg.XXXXXX")}"
export KDRILL_WORK="$tmp/work" KDRILL_STATE_DIR="$tmp/state" KDRILL_CACHE="${KDRILL_CACHE:-$tmp/cache}" KDRILL_HOME="$home"
mkdir -p "$KDRILL_WORK" "$KDRILL_STATE_DIR" "$KDRILL_CACHE"
ws="$KDRILL_WORK/llm-from-zero"
first="${1:-00}"; last="${2:-99}"
fail=0; n=0
echo "temp dir: $tmp"
for d in "$here"/lessons/*/; do
  id="$(basename "$d")"; num="${id%%-*}"
  [[ "$num" < "$first" || "$num" > "$last" ]] && continue
  n=$((n+1))
  "$KD" start "llm-from-zero/$id" >"$tmp/start.log" 2>&1 || { echo "FAIL $id: start"; tail -5 "$tmp/start.log"; fail=$((fail+1)); continue; }
  if "$KD" verify >"$tmp/v1.log" 2>&1; then
    echo "FAIL $id: verify PASSED on the untouched starter"; fail=$((fail+1))
  fi
  # apply the reference solution (everything except README.md)
  (cd "$d/solution" && find . -type f ! -name README.md -print0 | while IFS= read -r -d '' f; do
     mkdir -p "$ws/$(dirname "$f")"; cp "$f" "$ws/$f"; done)
  t0=$(date +%s)
  if "$KD" verify >"$tmp/v2.log" 2>&1; then
    printf 'ok   %-28s verify %3ss (fails on starter, passes with solution)\n' "$id" "$(( $(date +%s) - t0 ))"
  else
    echo "FAIL $id: verify failed with the reference solution"; cat "$tmp/v2.log"; fail=$((fail+1))
  fi
done
echo "lessons: $n, failures: $fail"
[[ -z "${KDRILL_REG_TMP:-}" ]] && echo "(temp dir kept: $tmp)"
exit $((fail > 0))
