source "$KDRILL_HOME/courses/kubeflow-trainer/lib.sh"
source "$KDRILL_HOME/courses/gpu-scheduling/lib.sh"
trainer_cleanup
kueue_cleanup
gpu_node gpu-1 l40s 2
gpu_node gpu-2 l40s 2
wait_nodes_ready
apply_labelled manifests/runtime.yaml
apply_labelled manifests/queues.yaml
baseline_set quota "$(jp clusterqueue.kueue.x-k8s.io/training-cq '{.spec.resourceGroups}')"
baseline_set runtime "$(jp $CTR/gpu-ddp '{.spec}' | cksum | cut -d' ' -f1)"
apply_lesson manifests/trainjobs.yaml
# Simulate two TrainJobs submitted at the same moment: the scheduler interleaves their pods, each job
# gets half of its nodes and both wait for the rest. (The Jobs are suspended now: start each with one
# pod, let the scheduler place both, then allow the second pod of each.)
wait_jobs() { [[ -n "$(kubectl get job llama-node-0 -o name 2>/dev/null)" && -n "$(kubectl get job mistral-node-0 -o name 2>/dev/null)" ]]; }
wait_until 60 wait_jobs || die "the JobSet controller did not create the Jobs"
kubectl patch job llama-node-0   --type merge -p '{"spec":{"parallelism":1}}' >/dev/null
kubectl patch job mistral-node-0 --type merge -p '{"spec":{"parallelism":1}}' >/dev/null
kubectl patch trainjob llama   --type merge -p '{"spec":{"suspend":false}}' >/dev/null
kubectl patch trainjob mistral --type merge -p '{"spec":{"suspend":false}}' >/dev/null
both_one() { [[ "$(running_count jobset.sigs.k8s.io/jobset-name=llama)$(running_count jobset.sigs.k8s.io/jobset-name=mistral)" == 11 ]]; }
wait_until 60 both_one || true
kubectl patch job llama-node-0   --type merge -p '{"spec":{"parallelism":2}}' >/dev/null
kubectl patch job mistral-node-0 --type merge -p '{"spec":{"parallelism":2}}' >/dev/null
sleep 3
info "llama and mistral each hold one node (2 GPUs) and wait for the other: kubectl get pods -o wide"
