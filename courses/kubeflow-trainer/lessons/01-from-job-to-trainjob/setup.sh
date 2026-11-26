source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
lesson_prep
trainer_cleanup
# The Job the team runs today, for comparison (about 15 s).
apply_lesson manifests/job.yaml
info "job/tiny-job runs the tiny GPT today; manifests/trainjob.yaml is the TrainJob to run instead"
