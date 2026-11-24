# Solution

From the lesson directory:

    kubectl apply -f solution/edge.yaml

- Gateway: listeners `https-shop` and `https-api`, both port 443, each with
  a `hostname` and its certificate Secret.
- HTTPRoutes `shop` and `api` attach to their HTTPS listener with
  `sectionName`; without it they would attach to every listener whose
  hostname matches, including plain HTTP.
- HTTPRoute `to-https` attaches to `http` only and redirects to https.
- ClientTrafficPolicy `edge-clients`: `tls.minVersion: "1.3"`.

In Envoy (port-forward to `deploy/edge`): one listener on 10443 with a
filter chain per hostname (`server_names`), each with a
`DownstreamTlsContext` whose certificate comes over **SDS** from Envoy
Gateway (`config_dump?resource=dynamic_active_secrets`), exactly the
structure you built by hand in lesson 16. Rotating the Secret pushes the
new certificate over SDS; no restart, no new pods.

Notes:
- `tls.mode: Passthrough` (with TLSRoute, lesson 34) forwards TLS without
  terminating it.
- A certificate Secret in another namespace needs a ReferenceGrant in that
  namespace.
- ClientTrafficPolicy is everything about the client side of the Gateway:
  TLS versions, ciphers, ALPN, client certificate validation (mTLS),
  HTTP/1.1, HTTP/2 and HTTP/3 settings, timeouts, connection limits, client
  IP detection (lesson 32), path normalisation.
- Backend TLS (lesson 17's mTLS to the upstream) is a Gateway API
  `BackendTLSPolicy` attached to the Service.
