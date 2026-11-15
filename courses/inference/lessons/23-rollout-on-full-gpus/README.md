# Rolling a model when every GPU is in use

Fake pods on fake GPU nodes (**no request is ever served**).

## Concept

Lesson 12 showed the options when a rollout cannot surge: run with fewer replicas
for a while. When fewer is not acceptable (the load needs all four replicas, the SLA allows no
dip), you need **spare capacity**: at least one free GPU somewhere so that a new replica can
start before an old one stops.

Common ways to have it without wasting much:

- a small **spare pool**: nodes tainted so normal workloads do not use them
  (`capacity=spare:NoSchedule`), used by rollouts, drains and failures; often spot nodes or reserved
  capacity that is cheap when idle;
- an **autoscaler** that adds a node when a surge pod is Pending (Karpenter,
  cluster-autoscaler), which costs a node start-up time per rollout step;
- permanent **N+1**: one replica more than the load needs.

The pieces of a taint-based pool are the usual ones: a **taint** on the spare node repels everything that
does not **tolerate** it; the model Deployment tolerates it, and `maxSurge` lets the rollout actually ask for
the extra pod. A **PodDisruptionBudget** protects the capacity floor against node drains and other evictions
that do not go through the Deployment's own strategy.

## The situation

`main-1` has 4 GPUs and runs the 4 replicas of `llm` (1 GPU each). `spare-1` has 2 GPUs, tainted
`capacity=spare:NoSchedule`. The Deployment's strategy is `maxSurge: 0, maxUnavailable: 1`: each rollout runs with 3 replicas
for a while.

## Your task

- `maxSurge` at least 1 and `maxUnavailable: 0`;
- a toleration for `capacity=spare:NoSchedule`;
- a PodDisruptionBudget on `app=llm` with `minAvailable: 4`;
- verify then rolls out `v2` itself: it must finish within 60 s, never with fewer than 4 ready
  replicas, and a replica must have run on `spare-1` (the surge).

## Useful commands

    kubectl get nodes -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu,TAINTS:.spec.taints[*].key'
    kubectl get pods -o wide -w
    kubectl set env deploy/llm MODEL_VERSION=v9
    kubectl rollout status deploy/llm

When you think you're done: `kdrill verify`

## On a real cluster

A surge pod for a large model also pays the image pull and weight load (lesson 10): pre-pull the
image on the spare node and keep weights cached there, or the "surge" step takes minutes. Use `minReadySeconds`
and `progressDeadlineSeconds` so a bad version is noticed.

## Read more

- https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment
- https://kubernetes.io/docs/tasks/run-application/configure-pdb/
