Look at what Envoy thinks the cluster is, and where requests land:

    kubectl exec client -- curl -s envoy:9901/clusters | grep '::cx_active'
    kubectl get pods -l app=echo -o wide
    kubectl exec client -- hits -p -n 30 http://envoy:10000/

One host, the Service's ClusterIP. Envoy balances between hosts; with one
host there is nothing to balance, and kube-proxy picks a pod once per
upstream *connection*, which Envoy keeps open and reuses.
---
A Service with `clusterIP: None` (headless) has no virtual IP: its DNS
name resolves to the IPs of all ready pods. Create one for `app: echo`
(port 80 -> targetPort `http`), and point the STRICT_DNS cluster at it.
Optionally set `dns_refresh_rate: 2s` on the cluster.

    kubectl run tmp --rm -it --image=curlimages/curl:8.22.0 --restart=Never -- nslookup echo-pods
---
    kubectl apply -f solution/echo-pods.yaml          # from the lesson directory
    kubectl apply -f solution/envoy-config.yaml
    kubectl rollout restart deploy/envoy && kubectl rollout status deploy/envoy
