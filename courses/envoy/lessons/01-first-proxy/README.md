# Your first Envoy: listener, connection manager, route, cluster

## Concept

Envoy is a proxy configured as a tree of a few object types. Learn these
names once and every Envoy config (and later, every Envoy Gateway or Istio
config dump) reads the same way:

- **Listener**: an address and port Envoy accepts connections on. A
  listener has one or more **filter chains**; a chain is a list of
  **network filters** that handle the bytes of a connection.
- **HTTP connection manager (HCM)**: the network filter that turns bytes
  into HTTP requests (HTTP/1.1, HTTP/2, HTTP/3). It owns a chain of **HTTP
  filters** (auth, rate limiting, ...) that always ends with the **router**.
- **Route configuration**: a list of **virtual hosts**, each matching a set
  of Host header values (`domains`), each with an ordered list of
  **routes**. A route has a `match` (path prefix, headers, ...) and an
  action, usually `route: {cluster: X}`.
- **Cluster**: a named group of upstream **hosts** (endpoints) plus how to
  find them (discovery type), how to balance between them, and how to
  connect (timeouts, TLS, limits).

Everything above lives under `static_resources` in a bootstrap file, read
once at start. Later lessons swap parts of it for dynamic resources (xDS),
which is how Envoy Gateway and Istio program Envoy, but the objects are
the same.

A cluster of `type: STRICT_DNS` resolves a DNS name and treats every address
it gets as a host, re-resolving periodically. Here the name `echo` resolves
through the pod's normal Kubernetes DNS.

The **admin interface** (here on port 9901) shows what Envoy actually
runs: `/clusters`, `/config_dump`, `/stats`, `/ready`. It has no
authentication, so in production it is bound to localhost or protected.

## The situation

Namespace `lab` has a backend Deployment and Service `echo` (it answers
any request with its name and the request it received), a pod `client` to
send traffic from, and a Deployment `envoy` that runs the config in the
ConfigMap `envoy` (key `envoy.yaml`). The Service `envoy` exposes the
listener on port 10000 and the admin interface on 9901. Envoy keeps
crashing.

## Your task

Fix the ConfigMap `envoy` so that:

- Envoy starts and stays ready (one pod), running the current ConfigMap;
- it has a cluster `echo` whose hosts are the Service `echo` on port 80;
- every request to `http://envoy:10000/<any path>` is proxied to the echo
  backend and answered 200 (verify sends 20 and checks Envoy's own
  `cluster.echo.upstream_rq_200` counter).

## Useful commands

    kubectl logs deploy/envoy                       # why it crashed
    kubectl edit configmap envoy                    # change envoy.yaml
    kubectl rollout restart deploy/envoy            # Envoy reads static config only at start
    kubectl rollout status deploy/envoy
    kubectl exec client -- curl -s http://envoy:10000/
    kubectl exec client -- hits http://envoy:10000/        # 20 requests, summarised
    kubectl exec client -- curl -s envoy:9901/clusters
    kubectl port-forward svc/envoy 9901   # then open http://localhost:9901 in a browser

`hits` (in the client pod) sends N requests (`-n`, default 20) and counts
the answers by status and by which backend answered; `hits -h` lists its
options. Every lesson of this course uses it.

When you think you're done: `kdrill verify`

## On a real cluster

The lab runs one Envoy replica with `--concurrency 2` (two worker threads)
and a ClusterIP Service reached from a client pod in the cluster. An edge
Envoy in production sits behind a cloud load balancer (Service type
LoadBalancer), runs several replicas, and binds the admin interface to
127.0.0.1.

## Read more

- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/life_of_a_request
- https://www.envoyproxy.io/docs/envoy/v1.39.5/start/quick-start/configuration-static
- https://www.envoyproxy.io/docs/envoy/v1.39.5/intro/arch_overview/upstream/service_discovery
- https://www.envoyproxy.io/docs/envoy/v1.39.5/operations/admin
