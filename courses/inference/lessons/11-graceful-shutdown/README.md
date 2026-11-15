# Graceful shutdown: zero dropped requests during a rollout

Model server: **simulator** (each answer takes about 4.5 s).

## Concept

A web request lasts milliseconds, so Kubernetes' default shutdown behaviour
(SIGTERM, 30 s grace, SIGKILL) is invisible. An LLM request lasts seconds to
minutes: a rollout, a scale-down or a node drain that stops a replica kills
every generation in progress on it, and the user sees a half-written answer
or an error. Scaling down on queue length (lesson 09) and rolling out new model
versions both do this routinely, so shutdown must be designed.

The sequence when a pod is deleted:

1. it is marked terminating, which starts two *independent* processes: removal
   from Service endpoints (taking a moment to reach kube-proxy or the gateway
   on every node) and the **preStop hook**;
2. after the hook the container gets **SIGTERM**;
3. after `terminationGracePeriodSeconds` in total it gets **SIGKILL**.

Two failures follow. A grace period shorter than a request kills it in flight. And
because endpoint removal and SIGTERM race, requests can still arrive at a server that
has already stopped listening. The standard fix is a `preStop` sleep (a few
seconds) in which the pod keeps serving while it disappears from every load
balancer, then SIGTERM and a drain, all inside a grace period sized for your
longest request. `lifecycle.preStop.sleep` needs no shell in the image.

Also remember the Deployment side: `maxUnavailable`/`maxSurge` decide how many
replicas are stopping at once (lesson 12), and a `PodDisruptionBudget` limits
voluntary evictions such as node drains.

## The situation

Deployment `llm` (2 replicas) answers each request in about 4.5 s and has
`terminationGracePeriodSeconds: 1` and no hook. Try it: send traffic with `ask -n 36 -c 6`
(six users at a time) and run `kubectl rollout restart deploy/llm` meanwhile.

## Your task

- a `preStop` hook that waits at least 6 s (`sleep`);
- a `terminationGracePeriodSeconds` of at least preStop + 8 s;
- model server settings unchanged;
- verify itself sends 36 requests from 6 users, restarts the Deployment in the
  middle, and requires all 36 to answer 200 and both replicas to be ready again.
  **It takes about 40 s.**

## Useful commands

    kubectl explain pod.spec.containers.lifecycle.preStop
    kubectl exec client -- ask -n 36 -c 6 -t 20 -w 25 http://llm/v1/chat/completions
    kubectl rollout restart deploy/llm
    kubectl get pods -w

When you think you're done: `kdrill verify`

## On a real cluster

Set the grace period to the longest generation you allow (minutes) and enforce
a maximum with `max_tokens` and gateway timeouts. For streaming, tell the
gateway to stop sending first (fail readiness in the preStop hook, then wait),
and make clients retry from the partial output. With a service mesh the sidecar
also needs to outlive the app (`EXIT_ON_ZERO_ACTIVE_CONNECTIONS`, native sidecars).

## Read more

- https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-termination
- https://kubernetes.io/docs/tasks/configure-pod-container/attach-handler-lifecycle-event/
- https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/
- https://learnkube.com/graceful-shutdown
