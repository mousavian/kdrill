# Cold starts: what scale-to-zero costs

Model server: **simulator** (a 20 s model load on purpose).

## Concept

Scaling a web server from 0 to 1 takes a second. Scaling a model server takes
as long as everything between "a request arrived" and "the model can answer":

1. a **node** with a free GPU (if the cluster has none: provisioning one, minutes);
2. the **image** pulled to that node (CUDA-based server images are 5-10 GB);
3. the **weights** read from a registry, object storage or a volume;
4. **loading and warm-up**: copying weights to the GPU, compiling kernels,
   capturing CUDA graphs;
5. the **probes** noticing, and the Service endpoint propagating.

So *scale to zero* saves money (idle GPUs are the expensive part) and costs a
first request that waits minutes, or fails. It also needs a component that can
receive a request while no pod exists and wake the model up (an *activator*:
KEDA's HTTP add-on, Knative, KServe's serverless mode). KEDA's metrics-api trigger
cannot do that: when nothing is running there is no metric to read.

The pragmatic answer: a **warm minimum** (`minReplicaCount: 1`, or more) for
models with latency expectations, scale-to-zero only for rarely used
ones, and to make every *additional* start as fast as possible: images
already on the node (pre-pull with a DaemonSet or bake them into the node image),
`imagePullPolicy: IfNotPresent`, weights from local storage or an image volume, and
probe periods that notice readiness quickly.

## The situation

`llm` has 0 replicas under a ScaledObject (`minReplicaCount: 0`). Its pod template
pulls with `imagePullPolicy: Always` and its startup probe runs every 10 s, so a
replica that finishes loading at 20 s is only noticed at 30 s.

## Your task

- keep at least one replica warm (ScaledObject);
- `imagePullPolicy: IfNotPresent`; startup probe period of 2 s or less (keep a 60 s budget);
- keep the 20 s load: `--startup-duration 20s` stays (you cannot negotiate it away);
- the Service answers three requests sent right now with 200, and the new
  pods become ready within 28 s of creation (20 s load + a few seconds for scheduling and probes).

## Useful commands

    kubectl get scaledobject,deploy,pods
    kubectl describe pod -l app=llm | grep -A12 Events:
    kubectl exec client -- ask -n 3 http://llm/v1/chat/completions
    kubectl get pods -w

When you think you're done: `kdrill verify` (up to a minute while the pod loads).

## On a real cluster

Cold start budgets of 2-10 minutes are normal for 70B models. Remedies: a pool of
pre-pulled nodes (placeholder/"balloon" pods that scale out ahead of demand),
fast weight loading (Run:ai Model Streamer, local NVMe cache), snapshotting a
warm container (checkpoint/restore, still experimental for GPUs), and
serverless platforms with an activator. Measure the phases from pod events
(`Pulling`, `Started`, readiness) before optimising any of them.

## Read more

- https://keda.sh/docs/2.21/concepts/scaling-deployments/#scaling-to-zero-and-idle
- https://github.com/kedacore/http-add-on
- https://kubernetes.io/docs/concepts/containers/images/#image-pull-policy
- https://knative.dev/docs/serving/autoscaling/scale-to-zero/
