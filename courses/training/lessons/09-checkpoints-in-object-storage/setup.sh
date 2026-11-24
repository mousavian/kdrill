source "$KDRILL_HOME/courses/training/lib.sh"
lesson_prep
info "starting MinIO..."
minio_up
kubectl create secret generic s3-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=kdrill-admin --from-literal=AWS_SECRET_ACCESS_KEY=kdrill-admin-secret >/dev/null
info "creating bucket checkpoints and a previous run's checkpoint (step 300; about 20 s)..."
kubectl apply -f - >/dev/null <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: previous-run
spec:
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: train
        image: $ML_IMAGE
        command: [sh, -c]
        args:
        - python3 -c "import boto3; s=boto3.client('s3'); [s.create_bucket(Bucket='checkpoints') for b in [0] if 'checkpoints' not in [x['Name'] for x in s.list_buckets().get('Buckets', [])]]"
          && exec train --seed 1 --log-every 100
        env:
        - {name: STEPS, value: "300"}
        - {name: CKPT_DIR, value: "s3://checkpoints/shakespeare"}
        - {name: CKPT_EVERY, value: "100"}
        - {name: AWS_ENDPOINT_URL, value: "http://minio:9000"}
        - {name: OMP_NUM_THREADS, value: "2"}
        envFrom: [{secretRef: {name: s3-credentials}}]
        resources:
          requests: {cpu: 500m, memory: 512Mi}
          limits: {cpu: "2", memory: 768Mi}
YAML
wait_job previous-run 180 || die "the previous run did not finish"
job_done previous-run || die "the previous run failed: kubectl logs job/previous-run"
kubectl delete job previous-run --wait=false >/dev/null
apply_lesson manifests/train.yaml
info "MinIO is at http://minio:9000; bucket checkpoints holds shakespeare/ckpt-000300.pt"
