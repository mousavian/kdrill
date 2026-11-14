source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
# Cluster-scoped Kueue objects the learner creates.
kueue_cleanup ml-cq -- a100
