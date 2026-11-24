# Runs once, on the first `kdrill start` of this course (and `kdrill course start`).
# The image is built by the engine (base/images/ml-dev/build.sh) before this runs.
source "$KDRILL_HOME/courses/llm-from-zero/lib.sh"
info "preparing the offline data cache (about 4 MB; falls back to the bundled books when offline)"
llm_prefetch
