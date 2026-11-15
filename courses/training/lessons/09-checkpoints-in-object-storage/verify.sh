source "$KDRILL_HOME/courses/training/lib.sh"
check "Job train exists" kubectl get job train
kubectl get job train >/dev/null 2>&1 || exit 1
check_eq "Checkpoints still go to s3://checkpoints/shakespeare" "s3://checkpoints/shakespeare" "$(env_of job/train CKPT_DIR)"
check_eq "STEPS is still 600" 600 "$(env_of job/train STEPS)"
check "The Job uses no PersistentVolumeClaim (object storage only)" test -z "$(jp job/train '{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}')"
ep="$(env_of job/train AWS_ENDPOINT_URL)"
check "AWS_ENDPOINT_URL points at the MinIO Service (got ${ep:-unset})" bash -c '[[ "$1" == http://minio:9000* || "$1" == http://minio.train* ]]' _ "$ep"
why "Without it the client talks to Amazon S3."
envfrom=" $(jp job/train '{.spec.template.spec.containers[0].envFrom[*].secretRef.name}') "
for k in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
  ref="$(jp job/train "{.spec.template.spec.containers[0].env[?(@.name==\"$k\")].valueFrom.secretKeyRef.name}")"
  lit="$(env_of job/train "$k")"
  check "$k comes from Secret s3-credentials, not a literal value" \
    bash -c '[[ -z "$3" && ( "$1" == s3-credentials || ( -z "$1" && "$2" == *" s3-credentials "* ) ) ]]' _ "$ref" "$envfrom" "$lit"
done
why "env[].valueFrom.secretKeyRef {name: s3-credentials, key: ...} or envFrom: [{secretRef: {name: s3-credentials}}]"
st="$(job_state train)"
if [[ "$st" == running || "$st" == pending ]]; then
  check "Job train has finished (still running, $(progress_msg train); about 20 s)" false
  exit 1
fi
check_eq "Job train completed" complete "$st"
why "kubectl logs job/train"
inspect_up --s3 s3-credentials
m=s3://checkpoints/shakespeare/metrics.json
check_eq "The bucket holds the finished run (metrics.json status, step)" "done 600" "$(mget $m status step | paste -sd' ' -)"
starts="$(mget1 $m runs | tr -d ' ' | grep -o '"start_step":[0-9]*' | cut -d: -f2 | paste -sd' ' -)"
check "The run resumed from the previous run's checkpoint at step 300 (attempts started at: ${starts:-?})" \
  bash -c '[[ " $1 " == *" 300 "* ]]' _ "$starts"
why "It must find shakespeare/ckpt-000300.pt in the bucket: same CKPT_DIR, same model settings."
check_eq "The newest checkpoint in the bucket is from step 600" 600 "$(ix mlt ckpt s3://checkpoints/shakespeare)"
inspect_down
