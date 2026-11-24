Step 1. The bootstrap keeps only `admin` and a `dynamic_resources` block
pointing at files; the listener and cluster move into those files, each
written as a DiscoveryResponse:

    # envoy.yaml (bootstrap)
    dynamic_resources:
      lds_config:
        resource_api_version: V3
        path_config_source: {path: /etc/envoy/lds.yaml, watched_directory: {path: /etc/envoy}}
      cds_config: ... cds.yaml ...

    # lds.yaml
    version_info: "1"
    resources:
    - "@type": type.googleapis.com/envoy.config.listener.v3.Listener
      name: main
      ...

Add `lds.yaml` and `cds.yaml` as keys of the ConfigMap `envoy` (it is
mounted at /etc/envoy), then restart Envoy once.
---
Step 2. Edit only `lds.yaml` and `cds.yaml` in the ConfigMap: a cluster
`echo-v2` and a route `prefix: /v2/` before the `/` route, and bump
`version_info`. Don't restart. If both change at once, Envoy may read
lds.yaml first and reject it (`route: unknown cluster 'echo-v2'` in the
log). Add the cluster first, wait until it shows up in
`config_dump?resource=dynamic_active_clusters`, then add the route. The kubelet updates the mounted files within
about a minute; poke it to do it now with

    kubectl annotate pod -l app=envoy kdrill.dev/poke="$(date +%s)" --overwrite

and watch `kubectl logs deploy/envoy -f` and
`curl envoy:9901/config_dump?resource=dynamic_active_clusters`.
---
    kubectl apply -f solution/step1-dynamic.yaml      # from the lesson directory
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
    kubectl apply -f solution/step2a-add-cluster.yaml
    kubectl annotate pod -l app=envoy kdrill.dev/poke="$(date +%s)" --overwrite
    # wait until echo-v2 is in config_dump?resource=dynamic_active_clusters
    kubectl apply -f solution/step2b-add-route.yaml
    kubectl annotate pod -l app=envoy kdrill.dev/poke="$(date +%s)" --overwrite
