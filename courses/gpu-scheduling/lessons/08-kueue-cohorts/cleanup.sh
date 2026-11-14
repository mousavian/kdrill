source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
# The ClusterQueues/flavor were created by setup (labelled); delete them in the
# right order so Kueue's finalizers don't hold up the generic cleanup.
kueue_cleanup team-a-cq team-b-cq -- h100
