# TLS on the Gateway: HTTPS listeners, redirects, ClientTrafficPolicy

## Concept

TLS termination is part of the Gateway: a listener with
`protocol: HTTPS`, a `port`, usually a `hostname`, and
`tls: {mode: Terminate, certificateRefs: [...]}` pointing to Secrets of
type `kubernetes.io/tls`. Several HTTPS listeners can share a port when
their hostnames differ; Envoy then has one filter chain per hostname and
picks the certificate by **SNI** (lesson 16, now generated for you).
Certificates reach Envoy over SDS, so a renewed Secret (cert-manager does
that) is picked up without restarts.

Routes choose listeners with `parentRefs[].sectionName`. Without it, a
route attaches to every listener of the Gateway its hostnames fit,
plain HTTP included. The common pattern: app routes on the HTTPS listeners,
and one route on the HTTP listener that only redirects to https.

What core Gateway API doesn't say about the client side (minimum TLS
version, ciphers, ALPN, client certificates, HTTP/2 and HTTP/3 settings,
timeouts, connection limits, client IP detection) goes into Envoy
Gateway's **ClientTrafficPolicy**, attached to a Gateway or one of its
listeners.

## The situation

Secrets `shop-tls` and `api-tls` hold certificates for `shop.lab` and
`api.lab` from a lab CA (the client pod trusts it at `/certs/ca.crt`).
Gateway `edge` has only an HTTP listener; HTTPRoutes `shop` and `api` serve
the two hosts over plain HTTP.

## Your task

- `https://shop.lab` and `https://api.lab` on port 443 of the Gateway, each
  with its own certificate, reach their backends; HTTP/2 works;
- plain HTTP for both hosts answers 301 to the https URL, and no longer
  reaches the backends;
- a ClientTrafficPolicy on the Gateway makes TLS 1.3 the minimum (a client
  limited to TLS 1.2 is refused).

## Useful commands

    kubectl exec client -- curl -sv --cacert /certs/ca.crt --connect-to shop.lab:443:edge:443 https://shop.lab/
    kubectl exec client -- curl -s -o /dev/null -w '%{http_code}\n' --tls-max 1.2 --cacert /certs/ca.crt --connect-to api.lab:443:edge:443 https://api.lab/
    kubectl exec client -- curl -si http://edge/ -H 'Host: shop.lab'
    kubectl get gateway edge -o yaml           # listener status
    kubectl explain clienttrafficpolicy.spec.tls

When you think you're done: `kdrill verify`

## On a real cluster

Certificates come from cert-manager (ACME/Let's Encrypt or an internal CA)
via the `cert-manager.io/issuer` annotation on the Gateway, and port 443 is
exposed through a LoadBalancer Service. Here a lab CA made by
`kdrill start` signs them and the client pod reaches the ClusterIP.

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/security/secure-gateways/
- https://gateway.envoyproxy.io/v1.9/tasks/traffic/client-traffic-policy/
- https://gateway-api.sigs.k8s.io/guides/tls/
- https://gateway.envoyproxy.io/v1.9/tasks/security/tls-cert-manager/
