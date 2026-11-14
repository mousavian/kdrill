# Solution

From the lesson directory:

    kubectl apply -f solution/policies.yaml

- ClientTrafficPolicy `behind-lb` on the Gateway:
  `clientIPDetection.xForwardedFor.numTrustedHops: 1`. Envoy Gateway sets
  the HCM's `use_remote_address: true` and `xff_num_trusted_hops: 1`: with
  one trusted proxy in front, the client is the rightmost XFF entry (the
  one that proxy appended).
- SecurityPolicy `admin-office-only` on the HTTPRoute `admin`: deny by
  default, allow `clientCIDRs: ["203.0.113.0/24"]`. That's an RBAC policy
  on the client address Envoy determined.

Why the spoofing case is denied: XFF is a list that each proxy appends to.
The client can put anything in it, so only the entries added by proxies you
operate are trustworthy. With one trusted proxy, everything left of the
last entry is client-controlled. Setting `numTrustedHops` higher than the
real number of proxies is how IP allow-lists get bypassed.

Notes:
- Alternatives: `trustedCIDRs` (trust XFF entries from known proxy ranges),
  `customHeader` (e.g. a CDN's `CF-Connecting-IP`), or the PROXY protocol
  (`enableProxyProtocol`) when the load balancer is L4.
- On a Service of type LoadBalancer, also mind
  `externalTrafficPolicy: Local`, or kube-proxy SNATs the client address
  away before Envoy ever sees it.
- The same client address feeds access logs (`%DOWNSTREAM_REMOTE_ADDRESS%`),
  rate limits by `sourceCIDR`, and geo-IP authorization.
