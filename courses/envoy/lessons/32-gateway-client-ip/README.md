# ClientTrafficPolicy: who is the client? (X-Forwarded-For and IP allow-lists)

## Concept

IP-based decisions (allow-lists, rate limits per client, geo rules, audit
logs) are only as good as Envoy's idea of the **client address**. Behind a
load balancer or CDN, the TCP peer is the load balancer; the real client is
in the **X-Forwarded-For** header, a list where each proxy appends the
address it received the request from:

    X-Forwarded-For: <what the client sent...>, <added by proxy 1>, ...

The client controls everything it sends, so only entries appended by
proxies you operate can be trusted. Envoy's rule (HCM
`use_remote_address` + `xff_num_trusted_hops`): with N trusted proxies in
front, the client address is the N-th entry from the right. Envoy uses
that address as the "downstream remote address" for RBAC, rate limits
and access logs.

In Envoy Gateway this is a **ClientTrafficPolicy** (everything about the
downstream side of a Gateway) with `clientIPDetection`:
`xForwardedFor.numTrustedHops` or `trustedCIDRs`, a `customHeader` (e.g.
a CDN's client IP header), or the PROXY protocol for L4 load balancers.
Without it, Envoy uses the TCP peer.

A **SecurityPolicy** can then authorize on it:
`authorization.rules[].principal.clientCIDRs`.

## The situation

Gateway `edge`, HTTPRoute `site` (`www.lab`, everything to `web`) and
HTTPRoute `admin` (`www.lab/admin` to the `admin` backend). In production
there is exactly one L7 load balancer in front of the Gateway, appending
the client address to X-Forwarded-For. Here the client pod plays that load
balancer: it sends the `X-Forwarded-For` header the load balancer would.

## Your task

- a ClientTrafficPolicy on the Gateway makes Envoy take the client address
  from X-Forwarded-For, trusting exactly one proxy;
- a SecurityPolicy on the HTTPRoute `admin` allows only clients from
  `203.0.113.0/24`: XFF `203.0.113.7` gets 200; `198.51.100.9`, no XFF,
  and the spoof `203.0.113.7, 198.51.100.9` get 403;
- the rest of the site stays open, and the Gateway's access log (Envoy
  Gateway logs JSON to the envoy container's stdout by default) records the
  client address from X-Forwarded-For as `downstream_remote_address`.

## Useful commands

    kubectl exec client -- curl -si http://edge/admin/users -H 'Host: www.lab' -H 'X-Forwarded-For: 203.0.113.7'
    kubectl exec client -- curl -s http://edge/ -H 'Host: www.lab' -H 'X-Forwarded-For: 198.51.100.9' | grep -i forwarded
    kubectl logs deploy/edge -c envoy --tail=3
    kubectl explain clienttrafficpolicy.spec.clientIPDetection
    kubectl get clienttrafficpolicy,securitypolicy -o yaml

When you think you're done: `kdrill verify` (up to 15 s: Envoy flushes file access logs every 10 s).

## On a real cluster

The load balancer is real and adds the header itself; count your actual
proxy hops (CDN + cloud LB = 2), or trust their CIDRs. For L4 load
balancers, use the PROXY protocol or `externalTrafficPolicy: Local` on the
Service so the client IP survives.

## Read more

- https://gateway.envoyproxy.io/v1.9/tasks/traffic/client-traffic-policy/
- https://gateway.envoyproxy.io/v1.9/tasks/security/restrict-ip-access/
- https://www.envoyproxy.io/docs/envoy/v1.39.5/configuration/http/http_conn_man/headers#x-forwarded-for
