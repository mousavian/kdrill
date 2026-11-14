# TLS passthrough with TLSRoute

## Concept

Not every workload wants the Gateway to terminate TLS: some authenticate
clients by certificate themselves, some must keep their keys, some speak
other protocols over TLS. For them the Gateway API has **TLS
passthrough**:

- a listener with `protocol: TLS` and `tls.mode: Passthrough` (no
  certificate on the Gateway);
- **TLSRoutes** that match the SNI server name (`hostnames`) and send the
  still-encrypted connection to `backendRefs`.

Route kinds and listener protocols must fit: HTTP/HTTPS listeners accept
HTTPRoute and GRPCRoute, TLS listeners TLSRoute (and HTTPRoute in Terminate
mode), TCP listeners TCPRoute, UDP listeners UDPRoute. A route attached to
a listener that doesn't allow its kind reports `Accepted: False` with
reason `NotAllowedByListeners`; `allowedRoutes.kinds` can narrow it further.

Envoy Gateway compiles this into exactly what you built in lesson 18: a
`tls_inspector`, a filter chain per server name, and a `tcp_proxy`.

The price of passthrough is visibility: the Gateway sees only SNI and
bytes, so there are no paths, headers, retries, HTTP access logs or
authentication at the edge. Choose it deliberately, per hostname, and keep
Terminate for everything else on the same Gateway.

## The situation

`site-a` and `site-b` serve HTTPS on port 443 with certificates for
`a.lab` and `b.lab` (the client pod trusts the lab CA at `/certs/ca.crt`).
Gateway `edge` has only an HTTP listener; a TLSRoute `site-a` exists but
isn't working.

## Your task

- the Gateway has a TLS listener on port 443 in Passthrough mode (no
  certificate on the Gateway);
- TLSRoutes `site-a` (`a.lab`) and `site-b` (`b.lab`) are Accepted with
  resolved references;
- TLS connections to the Gateway on 443 reach site-a or site-b by SNI, and
  the client sees each backend's own certificate; other names are refused.

## Useful commands

    kubectl get gateway edge -o yaml
    kubectl get tlsroute -o yaml
    kubectl exec client -- curl -sv --cacert /certs/ca.crt --connect-to a.lab:443:edge:443 https://a.lab/
    kubectl explain tlsroute.spec --api-version=gateway.networking.k8s.io/v1

When you think you're done: `kdrill verify`

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/security/tls-passthrough/
- https://gateway-api.sigs.k8s.io/guides/tls/
- https://gateway.envoyproxy.io/v1.9/tasks/traffic/tcp-routing/
