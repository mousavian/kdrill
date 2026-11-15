# Honest startup: startup, liveness and readiness probes

Model server: **simulator** (llm-d-inference-sim, with a 15 s load time on purpose).

## Concept

A web service is ready a second after it starts; a model server is not. It first
reads the weights (seconds for a 135M model, minutes for a 70B one, tens of
minutes when they come from object storage), moves them to the GPU and warms
up. Kubernetes' three probes answer three different questions and model servers
make mixing them up expensive:

- **startupProbe**: "has the process finished starting?" Liveness and readiness
  are switched off until it succeeds. Give it a budget
  (`failureThreshold x periodSeconds`) larger than the slowest load you expect.
- **livenessProbe**: "is the process stuck?" A failure restarts the container,
  which for a model server means loading everything again, so liveness should be
  slow to anger and must not look at anything that is merely busy or loading.
- **readinessProbe**: "may it get traffic?" A failure only removes the pod from
  Service endpoints. This is the one that should say "the model is loaded".

vLLM exposes `GET /health` (the process is up and the engine answers); the
simulator in this lab adds the distinction a loading server has, with `/health`
200 from the start and `/health/ready` 503 until `--startup-duration` has
passed. llama.cpp answers 503 on `/health` while it loads its model.

## The situation

Deployment `llm` (2 replicas) and Service `llm`. The liveness probe calls
`/health/ready` every 3 s and tolerates 2 failures, so it kills each pod about 9
seconds into a 15-second load: the pods restart forever. The readiness probe is
a `tcpSocket`, so even a surviving pod would be sent traffic before it is ready.

## Your task

Edit the Deployment so that, with no other change:

- `startupProbe` is an `httpGet` on `/health/ready` with a budget of at least 30 s;
- `livenessProbe` is an `httpGet` that does not use `/health/ready`;
- `readinessProbe` is an `httpGet` on `/health/ready`;
- both replicas become ready, with 0 restarts, and each took at least 12 s from
  container start to Ready;
- the Service has 2 ready endpoints and answers completions.

A passing verify needs the new pods to finish loading: allow up to a minute.

## Useful commands

    kubectl get pods -w
    kubectl describe pod -l app=llm
    kubectl get endpointslices -l kubernetes.io/service-name=llm

When you think you're done: `kdrill verify`

## On a real cluster

Budget generously: a startup probe of `failureThreshold: 360, periodSeconds: 5`
(30 minutes) is normal for big models loading from remote storage. Do not put
the probe on the inference endpoint itself (a probe request would occupy a
slot); vLLM's `/health`, TGI's `/health` and Triton's `/v2/health/ready` exist
for this. Also set `terminationGracePeriodSeconds` for draining (lesson 11).

## Read more

- https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- https://docs.vllm.ai/en/latest/serving/openai_compatible_server.html
- https://github.com/llm-d/llm-d-inference-sim/blob/main/docs/configuration.md
