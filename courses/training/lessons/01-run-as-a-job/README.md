# A training run is a Job, not a Deployment

## Concept

Serving and training look alike from Kubernetes' point of view (a container
that runs a Python process) but they end differently. A model server should
run forever: if it exits, something is wrong and it must be restarted. A
training run should run **once to completion**: when the process exits 0, the
work is done and nothing should be restarted.

A **Deployment** is for the first kind. Its pods always have
`restartPolicy: Always`, so a training script that finishes is simply started
again. The pod shows `Completed`, then `CrashLoopBackOff` (the kubelet backs
off restarts of containers that keep exiting), then trains the same model
from scratch, for ever. That wastes the CPU or GPU and overwrites the result.

A **Job** is for the second kind. It creates pods until `completions` of them
(default 1) have **succeeded**, then stops and records the `Complete`
condition. If a pod fails, the Job creates a new one, up to `backoffLimit`
times (default 6). Job pods must use `restartPolicy: Never` (a failed
container makes a new pod, each attempt is kept and can be inspected) or
`OnFailure` (the kubelet restarts the container in the same pod). The
finished pod stays around in `Completed` state, so its log, the
training curve and the final loss, can still be read with
`kubectl logs job/<name>`.

Every later lesson builds on this Job: data, checkpoints, retries, several
workers and queues are all Job (or Job-group) features.

## The situation

Namespace `train` has a Deployment `train` running the course's training
script (`train`, from the image `kdrill.local/ml-tiny:0.1.0`): 400 steps of a
character-level GPT with about 350,000 parameters on Shakespeare's plays,
seed 1, on one CPU. It takes about 30-60 seconds, prints the loss every 50
steps and ends with a line `done: step 400 final_loss=...`. Then the Deployment
starts it again.

## Your task

- Delete the Deployment `train`.
- Create a Job `train` with the same image, command, arguments, environment
  and resources, and `restartPolicy: Never` or `OnFailure`. It must train all
  400 steps (keep `--steps 400 --seed 1`), complete with a single pod, and end
  with a final loss below 2.9.
- Read the final loss from the Job's log and store it, exactly as printed, in
  ConfigMap `result`, key `final_loss`.

## Useful commands

    kubectl get deploy,pods
    kubectl logs deploy/train --previous | tail -n 3
    kubectl create job --help
    kubectl get job train -w
    kubectl logs job/train | tail -n 3

The Job takes 30-60 seconds; `kdrill verify` says so while it is still running.

## On a real cluster

The same Job runs a real training script on GPU nodes; the container then
also requests `nvidia.com/gpu`. Real runs take hours to weeks, so nobody reads
the loss from `kubectl logs`: they report to an experiment tracker (MLflow,
Weights & Biases) or to Prometheus (lesson 18). Job pods that finished are
kept until the Job is deleted; lesson 07 shows `ttlSecondsAfterFinished`.

## Read more

- https://kubernetes.io/docs/concepts/workloads/controllers/job/
- https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#restart-policy
- https://kubernetes.io/docs/tasks/job/
