source "$KDRILL_HOME/courses/training-platform/lib.sh"
lesson_prep
apply_lesson manifests/train.yaml
# Remember how fast the original run goes (tokens per second after 50 steps).
fast() { job_logs train | grep -q " step 50/"; }
wait_until 150 fast || die "the run did not reach step 50 in time"
tps="$(job_logs train | sed -n 's/.* step 50\/[0-9]* loss .* tok\/s \([0-9]*\).*/\1/p' | head -n 1)"
baseline_set tps "${tps:-0}"
# Does this node enforce CPU limits where the container can see them? (cgroup
# v2 hosts such as Docker Desktop do; some nested cgroup v1 hosts do not.)
if job_logs train | grep -q " cpu_limit=0.25 "; then baseline_set enforced yes; else baseline_set enforced no; fi
info "job/train runs at about ${tps:-?} tokens/s; 3000 steps would take a long time"
