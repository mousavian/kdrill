# Service discovery: let Envoy see every pod

## Concept

A cluster's **discovery type** decides where its hosts come from:

- `STATIC`: IPs written in the config.
- `STRICT_DNS`: Envoy resolves the name every `dns_refresh_rate` (5 s by
  default) and every address returned becomes a host. Hosts that disappear
  from DNS are removed.
- `LOGICAL_DNS`: resolve when a new connection is needed and use only the
  first address. Meant for big external services behind DNS.
- `EDS`: a control plane sends the endpoint list over xDS. This is what
  Envoy Gateway and Istio do: they watch Kubernetes EndpointSlices and push
  pod IPs.

In Kubernetes the difference that matters is **ClusterIP vs pod IPs**. A
normal Service name resolves to one virtual IP, and kube-proxy (iptables or
IPVS on each node) rewrites each new TCP *connection* to a random ready
pod. Envoy then sees a single host. All of its per-host machinery (load
balancing policies, health checks, outlier detection, per-host stats)
runs on that one fake host, and because Envoy reuses pooled upstream
connections, a few pods get most of the traffic. With HTTP/2 or gRPC
upstreams, one connection can carry everything.

A **headless Service** (`clusterIP: None`) has no virtual IP: its DNS name
answers with the IP of every ready pod, which is exactly what STRICT_DNS
wants. Pods that become ready appear in DNS; pods that fail readiness or
terminate disappear.

## The situation

Namespace `lab` runs 3 replicas of `echo` behind a normal Service `echo`.
Envoy's cluster `echo` is a STRICT_DNS cluster on the name `echo`.

## Your task

- Envoy's cluster `echo` contains exactly one host per running echo pod
  (pod IP, port 80), as `/clusters` shows;
- 30 requests through Envoy reach all 3 pods, each at least 6 times;
- when echo scales up, Envoy picks up the new pod by itself, within 25 s
  (verify scales echo to 4 replicas, then back to 3).

Keep the cluster name `echo`.

## Useful commands

    kubectl exec client -- hits -p -n 30 http://envoy:10000/       # -p: count by pod
    kubectl exec client -- curl -s envoy:9901/clusters | grep -E '::(cx_active|rq_total)'
    kubectl get pods -l app=echo -o wide
    kubectl get endpointslices -l kubernetes.io/service-name=echo
    kubectl run dns --rm -it --image=curlimages/curl:8.22.0 --restart=Never -- nslookup echo

When you think you're done: `kdrill verify`

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/upstream/service_discovery
- https://kubernetes.io/docs/concepts/services-networking/service/#headless-services
- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/upstream/connection_pooling
