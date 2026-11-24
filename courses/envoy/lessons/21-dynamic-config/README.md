# Dynamic configuration: xDS from files (LDS and CDS)

## Concept

So far every change meant a restart. Real Envoy deployments change
constantly (new routes, new backends, pods coming and going, rotated
certificates), so Envoy can receive its configuration dynamically through
the **xDS** APIs, one per resource type:

- **LDS**: listeners; **RDS**: route configurations; **CDS**: clusters;
  **EDS**: endpoints of a cluster; **SDS**: secrets (certificates);
- **ADS**: all of them over a single stream, so a management server can
  order updates (cluster before the route that uses it).

The bootstrap then only says who Envoy is, where the admin interface is,
and where each resource type comes from (`dynamic_resources`). A source can
be a gRPC **management server** (Envoy Gateway, istiod, go-control-plane)
or simply a **file** (`path_config_source`). Files use the same message as
the gRPC protocol, a `DiscoveryResponse`:

    version_info: "1"
    resources:
    - "@type": type.googleapis.com/envoy.config.cluster.v3.Cluster
      name: echo-v1
      ...

When the file changes, Envoy computes the difference and applies it live:
new clusters are **warmed** (DNS resolved, first health check) before
use; changed listeners get new filter chains while old connections
**drain**. A config Envoy can't accept is rejected and logged; the last
good version stays active. `config_dump` lists dynamic resources with
`version_info` and `last_updated`.

**Ordering matters.** Each resource type is its own subscription. If the
new route (LDS) arrives before the new cluster (CDS), the listener update
is rejected (`unknown cluster`) and stays rejected until the file changes
again. The rule is make-before-break: add clusters first, then the routes
that use them; remove routes first, then clusters. ADS exists so that a
management server can guarantee that order over one stream.

ConfigMap volumes are updated by the kubelet atomically, by swapping a
`..data` symlink; `watched_directory` makes Envoy notice that.

## The situation

Envoy runs a static config with a listener `main` and a cluster
`echo-v1`. A second backend `echo-v2` (`Name: v2`) is deployed.

## Your task

1. Convert Envoy to file-based dynamic resources: the bootstrap
   (`envoy.yaml`) has no static listeners or clusters; the listener `main`
   comes from LDS (`/etc/envoy/lds.yaml`) and the cluster `echo-v1` from CDS
   (`/etc/envoy/cds.yaml`). Put both files as extra keys into the ConfigMap
   `envoy` and restart Envoy once.
2. Then, **without restarting Envoy**, add a cluster `echo-v2` and a route
   `/v2/...` to it, by editing only `lds.yaml` and `cds.yaml`. Watch the
   Envoy log while you do it.

Result: `/v2/...` goes to v2, everything else to v1, and verify can see in
`config_dump` that `echo-v2` was added at least 5 s after Envoy started.

## Useful commands

    kubectl edit configmap envoy
    kubectl annotate pod -l app=envoy kdrill.dev/poke="$(date +%s)" --overwrite   # make the kubelet refresh the files now
    kubectl logs deploy/envoy -f
    kubectl exec client -- curl -s 'envoy:9901/config_dump?resource=dynamic_active_clusters'
    kubectl exec client -- curl -s 'envoy:9901/config_dump?resource=dynamic_listeners'
    kubectl exec client -- hits -n 5 http://envoy:10000/v2/x

The kubelet refreshes ConfigMap volumes on its own within about a minute;
the annotation makes it do so within seconds.

When you think you're done: `kdrill verify`

## On a real cluster

File-based xDS is rare in production (it shows up in sidecar-less setups
and tests). Normally a management server streams config over gRPC/ADS;
Part B uses Envoy Gateway, which does exactly that.

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/operations/dynamic_configuration
- https://www.envoyproxy.io/docs/envoy/v1.39.5/start/quick-start/configuration-dynamic-filesystem
- https://www.envoyproxy.io/docs/envoy/v1.39.5/api-docs/xds_protocol
