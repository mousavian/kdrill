# Rolling out a new model version when capacity is scarce

Model server: **simulator**.

## Concept

A Deployment's default rolling update is built for spare capacity: it creates up
to `maxSurge` (default 25%, rounded up) extra pods, waits for them to become
ready, then deletes old ones so that at most `maxUnavailable` (default 25%,
rounded down) are missing. Replacing a stateless web pod costs a few
milliseconds of extra CPU.

A model replica is different. It holds a whole GPU, and the cluster usually
has none spare: GPUs are expensive, scarce, and scaling the fleet takes
minutes (see the karpenter course). With `maxSurge >= 1` the surge pod stays Pending (or here,
is refused by a quota) and the rollout hangs half-way with no error on
the Deployment: the clue is in the ReplicaSet's events and in the pod's
`FailedScheduling`.

The options when you cannot surge:

- **`maxSurge: 0, maxUnavailable: N`**: stop N old replicas first. You run with N
  fewer replicas during the rollout: plan capacity for it, or scale up first.
- **blue/green** on a second set of GPUs (needs the spare capacity you do not
  have) or a **canary** that takes a share of traffic (lesson 19);
- **`minReadySeconds`** and good readiness probes (lesson 03) so a bad version
  stops the rollout instead of replacing every replica, and
  `progressDeadlineSeconds` to make a stuck rollout visible.

A **PodDisruptionBudget** protects the floor against *other* voluntary
disruptions (node drains, upgrades, the autoscaler): the Deployment controller
does not consult it for its own rolling update, but the eviction API does.

## The situation

The namespace `lab` has a ResourceQuota of 5 pods: the client plus four model
replicas, so no surge pod can ever be created. `setup` just rolled out version
`v2`; `kubectl rollout status deploy/llm` hangs.

## Your task

- `strategy`: RollingUpdate with `maxSurge: 0` and `maxUnavailable: 1`;
- `minReadySeconds` of at least 3;
- a PodDisruptionBudget on `app=llm` that allows at most one replica to be
  down (`minAvailable: 3` or `maxUnavailable: 1`);
- the stuck v2 rollout completes: four ready replicas on v2.

verify then rolls out `v3` itself and samples the ready count every second:
the rollout must finish within 90 s and never fall below 3 ready replicas
(about 40 s).

## Useful commands

    kubectl rollout status deploy/llm --timeout=20s
    kubectl describe rs -l app=llm | grep -i quota
    kubectl get resourcequota capacity
    kubectl explain deployment.spec.strategy.rollingUpdate

When you think you're done: `kdrill verify`

## On a real cluster

The quota is a stand-in for "no free GPU" (a pod requesting `nvidia.com/gpu: 1`
simply stays Pending). On a cloud with node autoscaling a surge pod triggers a
new GPU node, which works but takes minutes and costs money for the overlap;
many teams do exactly that for critical models and `maxSurge: 0` for the rest.

## Read more

- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment
- https://kubernetes.io/docs/tasks/run-application/configure-pdb/
- https://kubernetes.io/docs/concepts/policy/resource-quotas/
