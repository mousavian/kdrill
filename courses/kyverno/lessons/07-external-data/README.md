# External data: ConfigMap and API lookups in policies

## Concept

Hard-coding values in policies (approved namespaces, limits, registries)
turns every change into a policy change. Kyverno rules can load data into
variables first, with a **context** list evaluated before the rule:

    context:
    - name: limits                       # -> {{ limits.data.max }}
      configMap: {name: gpu-policy, namespace: platform}
    - name: nsLabels                     # -> {{ nsLabels.team }}
      apiCall:
        urlPath: "/api/v1/namespaces/{{ request.namespace }}"
        jmesPath: "metadata.labels"
    - name: count
      variable:
        jmesPath: "length(request.object.spec.containers)"

- **configMap**: the ConfigMap as an object (`.data.<key>`).
- **apiCall**: a GET (or POST) against the Kubernetes API (`urlPath`), a
  Service in the cluster (`service.url`), or an external URL. `jmesPath`
  trims the response. It runs as Kyverno's ServiceAccount, which needs RBAC
  for what it reads.
- **variable**: a computed value, with an optional `default`.
- **globalReference** reads a **GlobalContextEntry**, a cluster-wide,
  cached lookup shared by many policies.

Then use the variables anywhere: conditions, messages, patches. JMESPath
has functions for the glue: `length`, `sum`, `to_number`, `contains`,
`starts_with`, plus Kyverno extras such as `parse_json`,
`divide`, `time_since` and `semver_compare`. Try expressions with
`kyverno jp query`.

Lookups sit on the admission path, so every one costs latency and an API
request. Gate them with preconditions, and remember that a failed lookup
makes the rule error. Rules that read live state usually set
`background: false`.

The admission controller also hands you `request.userInfo`, `request.operation`
and `request.oldObject` (on UPDATE) without any lookup.

## The situation

ClusterPolicy `gpu-access` guards GPU Pods with two hard-coded rules:
`approved-namespace` allows GPUs only in a fixed list (`[ml-team]`), and
`max-gpus-per-pod` allows 8 GPUs, while the platform team's ConfigMap
`platform/gpu-policy` says `max-gpus-per-pod: "4"`. Approvals are supposed to
be the namespace label `gpu-access=approved` (`ml-team` has it, `web-team`
doesn't).

## Your task

Change `gpu-access` (keep the name and both rule names, both Enforce) so that,
for Pods where any container has a `nvidia.com/gpu` limit:

- they are admitted only if their namespace **currently** has the label
  `gpu-access=approved`; otherwise they're rejected with a message containing
  `namespace <name> is not approved for GPU workloads`;
- the total GPUs of the Pod may not exceed `max-gpus-per-pod` from
  `platform/gpu-policy` **as it is right now**; otherwise the message
  contains `at most <value> GPUs per Pod`.

Pods without GPUs are not affected. verify labels and relabels a throw-away
namespace `kyv-probe-gpu` and changes `max-gpus-per-pod` (8, 1, then back
to 4), so nothing may be hard-coded.

## Useful commands

    kubectl get ns -L gpu-access
    kubectl -n platform get configmap gpu-policy -o yaml
    kubectl get --raw /api/v1/namespaces/ml-team
    kubectl create --dry-run=server -f probes/gpu-6.yaml -n ml-team
    kubectl explain clusterpolicy.spec.rules.context

When you think you're done: `kdrill verify`

## Read more

- https://kyverno.io/docs/policy-types/cluster-policy/external-data-sources/
- https://kyverno.io/docs/policy-types/cluster-policy/jmespath/
- https://kyverno.io/docs/policy-types/global-context-caching/
