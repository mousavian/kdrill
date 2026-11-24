# Solution

From the lesson directory:

    kubectl apply -f solution/step1-dynamic.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
    # step 2a: the cluster first
    kubectl apply -f solution/step2a-add-cluster.yaml
    kubectl annotate pod -l app=envoy kdrill.dev/poke="$(date +%s)" --overwrite
    kubectl exec client -- curl -s 'envoy:9901/config_dump?resource=dynamic_active_clusters' | grep '"name"'
    # step 2b: then the route that uses it
    kubectl apply -f solution/step2b-add-route.yaml
    kubectl annotate pod -l app=envoy kdrill.dev/poke="$(date +%s)" --overwrite
    kubectl exec client -- hits -n 5 http://envoy:10000/v2/x

Step 1 turns the bootstrap into "admin + where to get my config":

    dynamic_resources:
      lds_config:
        resource_api_version: V3
        path_config_source:
          path: /etc/envoy/lds.yaml
          watched_directory: {path: /etc/envoy}
      cds_config: (same for cds.yaml)

and `lds.yaml` / `cds.yaml` hold DiscoveryResponses: a `version_info` and a
list of typed `resources`. Step 2 changes only those files, in two steps.
Changing both at once often fails: Envoy reads `lds.yaml` first, the route
refers to a cluster it doesn't have yet, and the listener update is
rejected (`lds: listener 'main' config rejected: route: unknown cluster
'echo-v2'`, stat `listener_manager.lds.update_rejected`). Cluster first,
then route: make-before-break.

What happened in step 2: the kubelet updated the ConfigMap volume by
writing a new timestamped directory and swapping the `..data` symlink.
Envoy watches the directory, re-reads the files, and applies the
difference: the new cluster is added and **warmed** (DNS resolved) before
the new listener config that references it takes effect; existing
connections are drained gracefully from the old listener version. No
restart, no dropped requests. `config_dump` shows each dynamic resource
with its `version_info` and `last_updated`, and a bad file is rejected
(logged, `lds.update_rejected` stat) while Envoy keeps the last good config.

The xDS family:
- **LDS** listeners, **RDS** route configurations (an HCM can use
  `rds:` instead of an inline `route_config`), **CDS** clusters, **EDS**
  endpoints (per cluster, `type: EDS`), **SDS** secrets (certificates),
  plus ECDS, VHDS, RTDS and others.
- Sources: files (here), or a gRPC management server, usually over
  **ADS** (aggregated: one stream for all types, so the server can order
  updates and avoid references to things Envoy doesn't have yet).
- The protocol (state-of-the-world or delta) carries `version_info`
  and nonces; Envoy ACKs or NACKs each update.

Envoy Gateway and Istio's istiod are such management servers: they watch
Kubernetes objects and stream LDS/RDS/CDS/EDS/SDS to their Envoys. That's
Part B.
