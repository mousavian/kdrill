# Kill and resume

## Concept

Pods of long training runs die for reasons that have nothing to do with the
training code: a node is drained for an upgrade, a spot instance is reclaimed,
the pod is preempted by something more important, a kernel panics. A Job
handles the first half of recovery by itself: when its pod fails or is
deleted, it creates a **new pod** (until `backoffLimit` is used up). The second
half is the program's job: the new pod must **resume** from the newest
checkpoint instead of starting over, otherwise every interruption throws away
all the work so far, and a run that is interrupted more often than it takes
to finish never finishes.

Resuming needs three things:

1. checkpoints on storage that outlives the pod (lesson 05);
2. a program that looks for the newest checkpoint at start and loads weights,
   optimizer state, step counter and random state from it;
3. a Job spec that does not defeat it (a "start fresh" flag, a checkpoint path
   that changes per pod, an emptyDir).

The replacement is a new pod: new name, possibly another node, empty
emptyDirs. (`restartPolicy: OnFailure` restarts a crashed container inside the
same pod, which keeps its emptyDir, but deletions, evictions and node failures
always produce a new pod.) A good restart is *idempotent*: running the same
Job again from any point gives the same end result.

The course's `train` resumes when `RESUME=auto` (the default) and appends one
entry per attempt to `runs` in `metrics.json` (`start_step`, `end_step`, host).

## The situation

PVC `checkpoints` exists. Job `train` (1000 steps, checkpoint every 100,
about 1-2 minutes) writes its checkpoints to an emptyDir and has
`RESUME=never`.

## Your task

- Make Job `train` resumable: keep `STEPS=1000` and `CKPT_EVERY=100`.
- While it trains, after step 200, **delete its pod** yourself.
- The Job's replacement pod must continue from a checkpoint (not step 0) and
  finish: Job Complete, with one lost pod in its status (`failed: 1`), and `metrics.json` on the PVC shows
  a second attempt that started at step 100 or later, ending `done` at 1000.

## Useful commands

    kubectl logs -f job/train
    kubectl delete pod -l batch.kubernetes.io/job-name=train
    kubectl get pods -l batch.kubernetes.io/job-name=train
    kubectl get job train -o jsonpath='{.status}'

A whole attempt takes about 2-3 minutes including the interruption.
`kdrill reset` starts over if the run finished before you interrupted it.

## On a real cluster

The cost of an interruption is the time since the last checkpoint, plus the
time to start a pod, pull a 10-20 GB image and load the checkpoint, times the
number of GPUs waiting. Teams tune the checkpoint interval against that,
keep checkpoints on shared storage reachable from every node, and use
`podReplacementPolicy: Failed` when a new pod must not start before the old one
has fully terminated (two writers on one checkpoint directory).

## Read more

- https://kubernetes.io/docs/concepts/workloads/controllers/job/#handling-pod-and-container-failures
- https://kubernetes.io/docs/concepts/workloads/controllers/job/#pod-replacement-policy
- https://docs.pytorch.org/tutorials/recipes/recipes/saving_and_loading_a_general_checkpoint.html
