# Capstone - a queued, resumable 2-node run with a planted fault

## Concept

Nothing new here: this lesson uses what the course taught, together.

- A **runtime** is the platform's template, a **TrainJob** is one run (lessons 1-3); both are immutable in the
  ways that matter: recreate the TrainJob after fixing a runtime.
- `mlPolicy.torch` plus a `torchrun` command make nodes one DDP group (lesson 4).
- A JobSet `failurePolicy` restarts the whole group, a volume mounted through `runtimePatches` and
  `CKPT_DIR` lets the new attempt resume (lesson 6).
- The queue label gets a TrainJob admitted as a unit, according to the **sum of its pods' requests**; the
  requests come from the runtime unless the TrainJob overrides them with `resourcesPerNode` (lessons 3 and 8).
- Debugging order: status conditions, then the JobSet and Jobs, then Workloads, then pod specs and logs.

A useful habit for a run that "does not do what it should": ask each layer what it believes. The TrainJob's
conditions say whether it is `Suspended`, `Failed` or `Complete`; the Workload says whether Kueue admitted it and, if
not, why (`kubectl describe workload`); the JobSet says how often it restarted; the pod's environment shows what
the controller injected; the logs show what the program did. Several faults can hide behind each other (a run that
is not admitted cannot show that it would not have trained as one group), so fix what you can see, recreate, and
look again.

## The situation

In namespace `train`: the PVC `checkpoints`; Kueue's LocalQueue `team` (ClusterQueue `team-cq`: 2 CPU, 4Gi);
the platform's runtime `capstone-ddp` (2 nodes) and the TrainJob `final-run` (800 steps, 2 nodes, checkpoint
every 50 steps). `final-run` has a planted fault: **rank 1 crashes at step 300, once**. Both were written in a
hurry; `final-run` is running now, and is wrong in several ways.

## Your task

Make `final-run` do what the team intended, without removing the planted fault, changing the queue, or replacing
the PVC:

- it is queued in `team` and **admitted**;
- the two nodes train as one PyTorch DDP group, injected by Trainer (not set by hand);
- a crash restarts the group, and the new attempt **resumes from a checkpoint**;
- it completes.

`kdrill verify` checks the queue, the PVC and the fault are as they were (`FAIL_AT_STEP=300`, `FAIL_RANK=1`,
`FAIL_ONCE=true`, 800 steps, 2 nodes); that the TrainJob is a new one with the queue label, a Workload owned by
it and admitted, and a CPU request per node that fits (total at most 2 CPU); that the runtime has the Torch
policy, a restart policy of 1-5 and launches `torchrun`; that the checkpoint volume is mounted; that the JobSet
restarted at least once and the TrainJob completed; and that `metrics.json` on the volume shows two attempts,
the last resumed from step 250 or later with 2 workers. It takes about 1.5 minutes; verify says where the run
is.

## Useful commands

    kubectl get trainjob,jobset,pods,workloads
    kubectl get workload -o yaml | grep -B2 -A8 "conditions:"
    kubectl logs -l jobset.sigs.k8s.io/jobset-name=final-run --prefix | grep -i "rank\|error\|resum"
    kubectl get jobset final-run -o jsonpath='{.status}'; echo
    kubectl explain trainjob.spec.trainer.resourcesPerNode

## On a real cluster

This is the shape of a production training submission: a platform-owned runtime (policy, launcher, restart
behaviour), a user-owned TrainJob (scale, arguments, storage), a queue in front, and checkpoints on shared
storage. What is left out here: GPUs and topology, the data initializer (lesson 5) and a model initializer,
metrics and alerting on `status.trainerStatus` and Kueue's metrics, authorization (who may create
TrainJobs in which namespaces, and which queues), and cleanup (`ttlSecondsAfterFinished`).

## Read more

- https://www.kubeflow.org/docs/components/trainer/overview/
- https://www.kubeflow.org/docs/components/trainer/operator-guides/runtime/
- https://kueue.sigs.k8s.io/docs/tasks/run/trainjobs/
- https://jobset.sigs.k8s.io/docs/concepts/
