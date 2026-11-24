# Solution

From the lesson directory:

    kubectl apply -f solution/edge.yaml

- Gateway: a listener `tls`, `protocol: TLS`, port 443,
  `tls.mode: Passthrough`, no certificateRefs.
- TLSRoutes `site-a` (`a.lab`) and `site-b` (`b.lab`) attached to it with
  `sectionName: tls`, each to its backend on port 443.

The original TLSRoute was attached to the HTTP listener, which only
accepts HTTP-type routes; its status said `NotAllowedByListeners`.

In Envoy (port-forward to `deploy/edge`): a listener on 10443 with the
`tls_inspector`, one filter chain per hostname (`server_names`) ending in a
`tcp_proxy` to the backend's cluster, no `DownstreamTlsContext`: lesson 18,
generated.

Notes:
- TLSRoute hostnames are matched against SNI only; there is no HTTP layer,
  so no paths, headers, retries or HTTP filters, and per-connection logs.
- `TCPRoute` (listener protocol TCP) is the same without SNI: one backend
  set per port. `UDPRoute` exists too (DNS, QUIC).
- TLSRoute reached the standard channel (v1) recently; this lab installs
  the experimental channel, which serves v1 alongside the older alpha
  versions.
