source "$KDRILL_HOME/courses/training-platform/lib.sh"
lesson_prep
apply_lesson manifests/pvcs.yaml
info "a previous run, shakespeare-v1, writes its checkpoints (about 30 s)..."
kubectl apply -f - >/dev/null <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: shakespeare-v1
spec:
  backoffLimit: 1
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: train
        image: $ML_IMAGE
        command: [train, --seed, "1", --log-every, "100"]
        env:
        - {name: STEPS, value: "600"}
        - {name: CKPT_DIR, value: /ckpt}
        - {name: CKPT_EVERY, value: "100"}
        - {name: RUN_NAME, value: shakespeare-v1}
        - {name: OMP_NUM_THREADS, value: "2"}
        resources:
          requests: {cpu: "1", memory: 512Mi}
          limits: {cpu: "2", memory: 768Mi}
        volumeMounts: [{name: ckpt, mountPath: /ckpt}]
      volumes:
      - {name: ckpt, persistentVolumeClaim: {claimName: checkpoints}}
YAML
wait_job shakespeare-v1 180 || die "shakespeare-v1 did not finish"
job_done shakespeare-v1 || die "shakespeare-v1 failed: kubectl logs job/shakespeare-v1"
apply_lesson manifests/train-v2.yaml
info "shakespeare-v2 started; manifests/sample.yaml samples from /models/shakespeare-v2"
