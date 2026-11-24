# Helpers for the llm-from-zero course (a kind: local course; no cluster).
# Lesson setup scripts source this file:  source "$KDRILL_HOME/courses/llm-from-zero/lib.sh"
# Written for bash 3.2.
#
# Environment from kdrill: KDRILL_WORKSPACE (the learner's directory, /work in the
# container), KDRILL_CACHE_DIR (offline cache, /cache in the container), KDRILL_BIN.

LLM_DIR="$KDRILL_HOME/courses/llm-from-zero"
LLM_DATA="$LLM_DIR/pylib/kdlib/data"

# llm_prefetch - make sure the offline cache has the pinned books: downloaded and
# checksum-verified, or (offline) the small bundled public-domain subset.
llm_prefetch() {
  mkdir -p "$KDRILL_CACHE_DIR"
  "$KDRILL_BIN" py --net --cache-rw -m kdlib.prefetch || info "(could not prepare the data cache; the bundled data will be used)"
}

# llm_seed_raw - copy the cached raw books to data/raw in the workspace when the
# learner has none there (skipped or failed lesson 01). Never overwrites.
llm_seed_raw() {
  local ws="$KDRILL_WORKSPACE" f n=0
  mkdir -p "$ws/data/raw"
  if [[ -z "$(ls -A "$ws/data/raw" 2>/dev/null)" ]]; then
    llm_prefetch
    for f in "$KDRILL_CACHE_DIR"/raw/*.txt; do
      [[ -f "$f" ]] || continue
      cp "$f" "$ws/data/raw/"; n=$((n+1))
    done
    if (( n == 0 )); then
      for f in "$LLM_DATA"/raw/*.txt.gz; do gzip -dc "$f" > "$ws/data/raw/$(basename "${f%.gz}")"; n=$((n+1)); done
    fi
    info "data/raw was empty: put $n book(s) from the offline cache there"
  fi
}

# llm_seed_splits - data/train.txt, val.txt, test.txt from the bundled cleaned
# corpus when the learner's pipeline (lessons 03-06) has not produced them.
llm_seed_splits() {
  local ws="$KDRILL_WORKSPACE" s
  mkdir -p "$ws/data"
  for s in train val test; do
    if [[ ! -s "$ws/data/$s.txt" ]]; then
      gzip -dc "$LLM_DATA/clean_$s.txt.gz" > "$ws/data/$s.txt"
      info "data/$s.txt did not exist: used the bundled cleaned corpus"
    fi
  done
}

# llm_setup none|sources|raw|splits - what a lesson needs in the workspace
llm_setup() {
  mkdir -p "$KDRILL_WORKSPACE/data"
  case "${1:-none}" in
    sources)
      [[ -f "$KDRILL_WORKSPACE/data/sources.json" ]] || cp "$LLM_DATA/sources.json" "$KDRILL_WORKSPACE/data/sources.json" ;;
    raw) llm_seed_raw ;;
    splits) llm_seed_splits ;;
  esac
}
