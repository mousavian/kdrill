# Solution

From the lesson directory:

    kubectl apply -f solution/scaledobject.yaml

Four changes to the ScaledObject:

    maxReplicaCount: 5               # was 2: room for 8 users / 2 slots = 4 replicas
    pollingInterval: 5               # was 30: how often KEDA reads the trigger
    advanced.horizontalPodAutoscalerConfig.behavior.scaleDown.stabilizationWindowSeconds: 15   # was 300
    triggers[0].metadata.valueLocation: inflight   # was running

The metric. KEDA's `metrics-api` scaler GETs a URL and reads one number from the
JSON (`valueLocation` is a path into it); the HPA that KEDA manages divides that
number by `targetValue` (an AverageValue target: total / target = replicas). The
aggregator stands in for Prometheus and sums every replica's `/metrics`:

- `running` (requests being generated) is at most `slots x replicas`, so with one
  replica it reads 2 however many users there are: ceil(2/2) = 1, forever.
- `waiting` (the queue) drops as soon as you add replicas, so the autoscaler adds
  replicas, sees the queue vanish, removes them, and the queue returns: flapping.
- `inflight` = running + waiting is the demand, independent of how many replicas
  currently exist: 8 users -> ceil(8 / 2) = 4 replicas, and it stays there.

Scale-down is deliberately slower than scale-up in production (the HPA default
stabilisation is 300 s: replicas hold for 5 minutes after load drops, so a short
dip does not throw away loaded GPUs). The lab shortens it to 15 s so that the
lesson finishes.
