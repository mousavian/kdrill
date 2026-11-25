# Runs once, on the first `kdrill start` of this course (and `kdrill course start`).
# The image is built by the engine (base/images/ml-dev/build.sh) before this runs.
source "$KDRILL_HOME/courses/fine-tuning/lib.sh"
info "preparing the workspace: bundled data and the base model (no download, a few seconds)"
ft_setup all
