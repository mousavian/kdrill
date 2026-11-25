# Helpers for the fine-tuning course (a kind: local course; no cluster).
# Lesson setup scripts source this file:  source "$KDRILL_HOME/courses/fine-tuning/lib.sh"
# Written for bash 3.2.
#
# Environment from kdrill: KDRILL_WORKSPACE (the learner's directory, /work in the container),
# KDRILL_WORK (the root of all workspaces), KDRILL_BIN.

FT_DIR="$KDRILL_HOME/courses/fine-tuning"
FT_DATA="$FT_DIR/pylib/kdlib/data"

# ft_seed_data - copy the bundled text and task files to data/ in the workspace. Never overwrites,
# so a learner can edit or replace them; delete a file to get the original back.
ft_seed_data() {
  local ws="$KDRILL_WORKSPACE" f name n=0
  mkdir -p "$ws/data"
  for f in "$FT_DATA"/alice_*.txt.gz "$FT_DATA"/holmes_*.txt.gz; do
    name="$(basename "${f%.gz}")"
    [[ -s "$ws/data/$name" ]] || { gzip -dc "$f" > "$ws/data/$name"; n=$((n+1)); }
  done
  for f in "$FT_DATA"/qa_*.jsonl "$FT_DATA"/pairs_*.jsonl "$FT_DATA"/facts.json; do
    name="$(basename "$f")"
    [[ -s "$ws/data/$name" ]] || { cp "$f" "$ws/data/$name"; n=$((n+1)); }
  done
  if (( n > 0 )); then info "put $n bundled data file(s) in data/"; fi
}

# ft_seed_base - base/checkpoint.pt: your llm-from-zero capstone model when it exists and fits this
# course (see kdlib/prepare_base.py), else the reference base model that ships with the course.
# Never replaces an existing base/checkpoint.pt (delete it to choose again).
ft_seed_base() {
  local ws="$KDRILL_WORKSPACE" mine="$KDRILL_WORK/llm-from-zero/out/capstone/checkpoint.pt"
  mkdir -p "$ws/base"
  if [[ -s "$ws/base/checkpoint.pt" ]]; then return 0; fi
  if [[ -s "$mine" ]]; then cp "$mine" "$ws/base/learner_checkpoint.pt"; fi
  "$KDRILL_BIN" py --course fine-tuning -m kdlib.prepare_base || return 1
  info "base model: $(head -n 1 "$ws/base/SOURCE.txt")"
}

# ft_setup none|data|base|all - what a lesson needs in the workspace
ft_setup() {
  mkdir -p "$KDRILL_WORKSPACE"
  case "${1:-none}" in
    data) ft_seed_data ;;
    base) ft_seed_base ;;
    all) ft_seed_data; ft_seed_base ;;
  esac
}

# ft_seed_sft - models/sft_mixed.pt, the starting point of the DPO lesson: made by lesson 14's run_prefs.py, or, when you have
# not run it, the reference SFT model that ships with the course. Never overwrites.
ft_seed_sft() {
  local ws="$KDRILL_WORKSPACE"
  mkdir -p "$ws/models"
  if [[ ! -s "$ws/models/sft_mixed.pt" ]]; then
    cp "$FT_DATA/ref_sft.pt" "$ws/models/sft_mixed.pt"
    info "models/sft_mixed.pt did not exist: used the reference SFT model that ships with the course"
  fi
}
